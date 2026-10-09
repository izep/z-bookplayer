import Foundation
import AVFoundation
import SwiftUI

@MainActor
public class LibraryManager: ObservableObject {
    public static let shared = LibraryManager()
    
    private let storageKey = "zbookplayer_saved_books"
    
    @Published public var books: [Book] = []
    @Published public var isScanning: Bool = false
    @Published public var errorMessage: String? = nil
    
    public init() {
        loadSavedBooks()
    }
    
    public func loadSavedBooks() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode([Book].self, from: data)
            self.books = decoded
        } catch {
            print("Failed to decode saved books: \(error)")
        }
    }
    
    public func saveBooks() {
        do {
            let data = try JSONEncoder().encode(books)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode books: \(error)")
        }
    }
    
    // MARK: - Add Book from Folder
    public func addBook(from folderURL: URL) async {
        isScanning = true
        errorMessage = nil
        
        let accessed = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let bookmark = try folderURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let bookTitle = folderURL.lastPathComponent
            
            // Check if book with this title already exists
            if let existingIndex = books.firstIndex(where: { $0.title == bookTitle }) {
                books[existingIndex].bookmarkData = bookmark
                await refreshBook(books[existingIndex])
                isScanning = false
                return
            }
            
            var newBook = Book(
                title: bookTitle,
                bookmarkData: bookmark
            )
            
            await scanFolderContents(folderURL: folderURL, book: &newBook)
            
            books.append(newBook)
            saveBooks()
        } catch {
            errorMessage = "Failed to add folder: \(error.localizedDescription)"
        }
        
        isScanning = false
    }
    
    // MARK: - Refresh Book (detect new chapters from iCloud Drive)
    public func refreshBook(_ book: Book) async {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        
        let (resolvedURL, isStale) = Self.resolveFolderURL(from: book.bookmarkData)
        guard let folderURL = resolvedURL else {
            errorMessage = "Could not resolve folder bookmark for '\(book.title)'"
            return
        }
        
        let accessed = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        if isStale {
            if let newBookmark = try? folderURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                books[index].bookmarkData = newBookmark
            }
        }
        
        var updatedBook = books[index]
        await scanFolderContents(folderURL: folderURL, book: &updatedBook)
        books[index] = updatedBook
        saveBooks()
    }
    
    public func refreshAllBooks() async {
        isScanning = true
        for book in books {
            await refreshBook(book)
        }
        isScanning = false
    }
    
    public func deleteBook(_ book: Book) {
        books.removeAll { $0.id == book.id }
        saveBooks()
    }
    
    public func updatePlaybackProgress(
        bookId: UUID,
        chapterId: String,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isCompleted: Bool
    ) {
        guard let bIndex = books.firstIndex(where: { $0.id == bookId }) else { return }
        guard let cIndex = books[bIndex].chapters.firstIndex(where: { $0.id == chapterId }) else { return }
        
        books[bIndex].chapters[cIndex].currentTime = currentTime
        if duration > 0 {
            books[bIndex].chapters[cIndex].duration = duration
        }
        books[bIndex].chapters[cIndex].isCompleted = isCompleted
        books[bIndex].lastPlayedChapterId = chapterId
        books[bIndex].lastPlayedDate = Date()
        
        saveBooks()
    }
    
    public func markChapterCompleted(bookId: UUID, chapterId: String, completed: Bool) {
        guard let bIndex = books.firstIndex(where: { $0.id == bookId }) else { return }
        guard let cIndex = books[bIndex].chapters.firstIndex(where: { $0.id == chapterId }) else { return }
        
        books[bIndex].chapters[cIndex].isCompleted = completed
        if completed {
            books[bIndex].chapters[cIndex].currentTime = books[bIndex].chapters[cIndex].duration
        } else {
            books[bIndex].chapters[cIndex].currentTime = 0
        }
        saveBooks()
    }
    
    // MARK: - Scan Folder
    private func scanFolderContents(folderURL: URL, book: inout Book) async {
        let fileManager = FileManager.default
        let supportedExtensions = Set(["mp3", "m4a", "m4b", "aac", "wav"])
        let imageExtensions = Set(["jpg", "jpeg", "png", "webp"])
        
        guard let items = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        var audioURLs: [URL] = []
        var coverFileName: String? = nil
        
        for item in items {
            let ext = item.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                audioURLs.append(item)
            } else if imageExtensions.contains(ext) {
                let name = item.deletingPathExtension().lastPathComponent.lowercased()
                if name.contains("cover") || name.contains("folder") || coverFileName == nil {
                    coverFileName = item.lastPathComponent
                }
            }
        }
        
        book.coverImageFileName = coverFileName
        
        // Existing chapter map for keeping progress
        let existingMap = Dictionary(uniqueKeysWithValues: book.chapters.map { ($0.fileName, $0) })
        var newChapters: [Chapter] = []
        
        for audioURL in audioURLs {
            let fileName = audioURL.lastPathComponent
            if let existing = existingMap[fileName] {
                var ch = existing
                if ch.duration <= 0 {
                    let d = await loadAudioDuration(for: audioURL)
                    if d > 0 {
                        ch.duration = d
                    }
                }
                newChapters.append(ch)
            } else {
                // New chapter detected!
                let cleanTitle = formatChapterTitle(from: fileName)
                let duration = await loadAudioDuration(for: audioURL)
                let newChapter = Chapter(
                    fileName: fileName,
                    title: cleanTitle,
                    duration: duration,
                    currentTime: 0,
                    isCompleted: false
                )
                newChapters.append(newChapter)
            }
        }
        
        // Sort naturally
        newChapters.sort(by: Chapter.naturalSortCompare)
        book.chapters = newChapters
    }
    
    private func loadAudioDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite ? seconds : 0
        } catch {
            return 0
        }
    }
    
    private func formatChapterTitle(from fileName: String) -> String {
        var base = (fileName as NSString).deletingPathExtension
        base = base.replacingOccurrences(of: "_", with: " ")
        base = base.replacingOccurrences(of: "-", with: " - ")
        // Normalize multiple spaces
        while base.contains("  ") {
            base = base.replacingOccurrences(of: "  ", with: " ")
        }
        return base.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Resolve Folder URL Helper
    public static func resolveFolderURL(from bookmarkData: Data) -> (url: URL?, isStale: Bool) {
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return (url, isStale)
        }
        return (nil, false)
    }
    
    // MARK: - Resolve File URL with Active Scope Access
    public func resolveURL(for book: Book, fileName: String) -> (url: URL?, stopAccess: () -> Void) {
        let (resolvedFolder, _) = Self.resolveFolderURL(from: book.bookmarkData)
        guard let folderURL = resolvedFolder else {
            return (nil, {})
        }
        
        let accessed = folderURL.startAccessingSecurityScopedResource()
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        let stopBlock: () -> Void = {
            if accessed {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        return (fileURL, stopBlock)
    }
}
