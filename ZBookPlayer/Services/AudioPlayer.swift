import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

public enum SleepTimerOption: Equatable {
    case off
    case minutes(Int)
    case endOfChapter
    
    public var label: String {
        switch self {
        case .off: return "Off"
        case .minutes(let m): return "\(m)m"
        case .endOfChapter: return "End of Chapter"
        }
    }
}

@MainActor
public class AudioPlayer: ObservableObject {
    public static let shared = AudioPlayer()
    
    // Playback state
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public var playbackRate: Float = 1.0
    @Published public private(set) var currentBook: Book? = nil
    @Published public private(set) var currentChapter: Chapter? = nil
    
    // Status & Error state
    @Published public var isDownloadingFromICloud: Bool = false
    @Published public var playbackErrorMessage: String? = nil
    
    // Sleep timer state
    @Published public private(set) var activeSleepTimer: SleepTimerOption = .off
    @Published public private(set) var sleepTimerRemaining: TimeInterval? = nil
    
    // Internal player
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var sleepTimerTask: Task<Void, Never>?
    private var activeSecurityScopedURL: URL?
    private var downloadTask: Task<Void, Never>?
    
    public init() {
        setupAudioSession()
        setupRemoteCommands()
        setupNotifications()
    }
    
    deinit {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
        }
        playerItemStatusObserver?.invalidate()
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Audio Session Setup
    public func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification: notification)
            }
        }
    }
    
    private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Playback Control
    public func playChapter(_ chapter: Chapter, in book: Book, startPosition: TimeInterval? = nil) {
        downloadTask?.cancel()
        downloadTask = nil
        playbackErrorMessage = nil
        isDownloadingFromICloud = false
        
        // Stop current resource access if changing book
        if activeSecurityScopedURL != nil {
            activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
        }
        
        // Resolve security-scoped folder URL
        let (folderURL, _) = LibraryManager.resolveFolderURL(from: book.bookmarkData)
        
        guard let resolvedFolder = folderURL else {
            playbackErrorMessage = "Could not resolve folder bookmark for '\(book.title)'"
            return
        }
        
        guard resolvedFolder.startAccessingSecurityScopedResource() else {
            playbackErrorMessage = "Cannot access security-scoped folder permissions."
            return
        }
        
        activeSecurityScopedURL = resolvedFolder
        currentBook = book
        currentChapter = chapter
        duration = chapter.duration
        
        let sourceFileURL = resolvedFolder.appendingPathComponent(chapter.fileName)
        
        downloadTask = Task { @MainActor in
            await prepareAndPlayFile(sourceURL: sourceFileURL, chapter: chapter, book: book, startPosition: startPosition)
        }
    }
    
    private func prepareAndPlayFile(sourceURL: URL, chapter: Chapter, book: Book, startPosition: TimeInterval?) async {
        // 1. Check if the file is downloaded from iCloud Drive
        var isReady = false
        let fileManager = FileManager.default
        
        // Check ubiquitous status
        if let values = try? sourceURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .fileSizeKey]) {
            let status = values.ubiquitousItemDownloadingStatus
            let fileSize = values.fileSize ?? 0
            
            if status == .notDownloaded || fileSize == 0 {
                isDownloadingFromICloud = true
                try? fileManager.startDownloadingUbiquitousItem(at: sourceURL)
                
                // Poll until downloaded or timeout (up to 30s)
                var attempts = 0
                while attempts < 60 && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    attempts += 1
                    
                    if let pollValues = try? sourceURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .fileSizeKey]),
                       pollValues.ubiquitousItemDownloadingStatus == .current,
                       (pollValues.fileSize ?? 0) > 0 {
                        isReady = true
                        break
                    }
                }
                isDownloadingFromICloud = false
            } else {
                isReady = true
            }
        } else {
            isReady = fileManager.fileExists(atPath: sourceURL.path)
        }
        
        if Task.isCancelled { return }
        
        // 2. Cache chapter to local application sandbox cache
        // Playing from app sandbox cache completely prevents mediaserverd sandbox violations!
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let bookCacheDir = cachesDir.appendingPathComponent(book.id.uuidString)
        try? fileManager.createDirectory(at: bookCacheDir, withIntermediateDirectories: true)
        let localCachedURL = bookCacheDir.appendingPathComponent(chapter.fileName)
        
        var playbackURL = sourceURL
        
        // If source file is readable, copy to local cache
        if isReady {
            let shouldCopy = !fileManager.fileExists(atPath: localCachedURL.path)
            if shouldCopy {
                try? fileManager.copyItem(at: sourceURL, to: localCachedURL)
            }
            if fileManager.fileExists(atPath: localCachedURL.path) {
                playbackURL = localCachedURL
            }
        }
        
        // 3. Load accurate duration if needed
        let asset = AVURLAsset(url: playbackURL)
        if let loadedDuration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(loadedDuration)
            if seconds.isFinite && seconds > 0 {
                self.duration = seconds
                LibraryManager.shared.updatePlaybackProgress(
                    bookId: book.id,
                    chapterId: chapter.id,
                    currentTime: chapter.currentTime,
                    duration: seconds,
                    isCompleted: chapter.isCompleted
                )
            }
        }
        
        // 4. Initialize AVPlayer with the file
        let playerItem = AVPlayerItem(asset: asset)
        cleanupTimeObserver()
        playerItemStatusObserver?.invalidate()
        
        avPlayer = AVPlayer(playerItem: playerItem)
        
        // Resume position
        let initialTime = startPosition ?? (chapter.isCompleted ? 0 : chapter.currentTime)
        if initialTime > 0 && initialTime < self.duration {
            let targetCMTime = CMTime(seconds: initialTime, preferredTimescale: 600)
            await avPlayer?.seek(to: targetCMTime, toleranceBefore: .zero, toleranceAfter: .zero)
            self.currentTime = initialTime
        } else {
            self.currentTime = 0
        }
        
        setupTimeObserver()
        setupEndObserver(for: playerItem)
        setupStatusObserver(for: playerItem)
        
        play()
        updateNowPlayingInfo()
    }
    
    private func setupStatusObserver(for item: AVPlayerItem) {
        playerItemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    self.playbackErrorMessage = nil
                case .failed:
                    let err = observedItem.error?.localizedDescription ?? "Playback failed"
                    print("AVPlayerItem error: \(err)")
                    self.playbackErrorMessage = err
                    self.isPlaying = false
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    public func play() {
        guard let player = avPlayer else { return }
        setupAudioSession()
        player.play()
        player.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    public func pause() {
        avPlayer?.pause()
        isPlaying = false
        saveCurrentProgress()
        updateNowPlayingInfo()
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func seek(to targetSeconds: TimeInterval) {
        guard let player = avPlayer else { return }
        let clamped = max(0, min(targetSeconds, duration > 0 ? duration : targetSeconds))
        let targetTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        saveCurrentProgress()
        updateNowPlayingInfo()
    }
    
    public func skip(seconds: Double) {
        seek(to: currentTime + seconds)
    }
    
    public func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            avPlayer?.rate = rate
        }
        updateNowPlayingInfo()
    }
    
    // MARK: - Next / Previous Chapter
    public func playNextChapter() {
        guard let book = currentBook, let chapter = currentChapter else { return }
        let chapters = book.chapters
        guard let currentIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              currentIndex + 1 < chapters.count else {
            pause()
            return
        }
        
        let nextChapter = chapters[currentIndex + 1]
        playChapter(nextChapter, in: book, startPosition: 0)
    }
    
    public func playPreviousChapter() {
        guard let book = currentBook, let chapter = currentChapter else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        let chapters = book.chapters
        guard let currentIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              currentIndex > 0 else {
            seek(to: 0)
            return
        }
        
        let prevChapter = chapters[currentIndex - 1]
        playChapter(prevChapter, in: book, startPosition: 0)
    }
    
    // MARK: - Progress Synchronization
    private func saveCurrentProgress() {
        guard let book = currentBook, let chapter = currentChapter else { return }
        let isComplete = duration > 0 && (currentTime >= duration - 5 || currentTime / duration >= 0.98)
        LibraryManager.shared.updatePlaybackProgress(
            bookId: book.id,
            chapterId: chapter.id,
            currentTime: currentTime,
            duration: duration,
            isCompleted: isComplete
        )
    }
    
    // MARK: - Time Observation
    private func setupTimeObserver() {
        guard let player = avPlayer else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                if let currentItem = self.avPlayer?.currentItem {
                    let itemDuration = CMTimeGetSeconds(currentItem.duration)
                    if itemDuration.isFinite && itemDuration > 0 {
                        self.duration = itemDuration
                    }
                }
                if Int(seconds) % 5 == 0 {
                    self.saveCurrentProgress()
                }
            }
        }
    }
    
    private func cleanupTimeObserver() {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func setupEndObserver(for item: AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleChapterEnded()
            }
        }
    }
    
    private func handleChapterEnded() {
        guard let book = currentBook, let chapter = currentChapter else { return }
        
        LibraryManager.shared.updatePlaybackProgress(
            bookId: book.id,
            chapterId: chapter.id,
            currentTime: duration,
            duration: duration,
            isCompleted: true
        )
        
        if activeSleepTimer == .endOfChapter {
            setSleepTimer(.off)
            pause()
            return
        }
        
        playNextChapter()
    }
    
    // MARK: - Sleep Timer
    public func setSleepTimer(_ option: SleepTimerOption) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        activeSleepTimer = option
        
        switch option {
        case .off, .endOfChapter:
            sleepTimerRemaining = nil
        case .minutes(let mins):
            let totalSeconds = TimeInterval(mins * 60)
            sleepTimerRemaining = totalSeconds
            sleepTimerTask = Task { @MainActor in
                var remaining = totalSeconds
                while remaining > 0 && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    remaining -= 1
                    self.sleepTimerRemaining = remaining
                }
                if !Task.isCancelled {
                    self.activeSleepTimer = .off
                    self.sleepTimerRemaining = nil
                    self.pause()
                }
            }
        }
    }
    
    // MARK: - Now Playing Info & Lock Screen Controls
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: 30) }
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: -15) }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNextChapter() }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPreviousChapter() }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        
        let title = currentChapter?.title ?? "No Chapter"
        let artist = currentBook?.title ?? "Audiobook"
        
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyAlbumTitle] = artist
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        if let book = currentBook, let coverName = book.coverImageFileName,
           let folder = activeSecurityScopedURL {
            let coverURL = folder.appendingPathComponent(coverName)
            if let image = UIImage(contentsOfFile: coverURL.path) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
