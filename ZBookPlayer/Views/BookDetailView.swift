import SwiftUI

public struct BookDetailView: View {
    public let bookId: UUID
    @ObservedObject var library = LibraryManager.shared
    @ObservedObject var player = AudioPlayer.shared
    
    @State private var searchText: String = ""
    @State private var filterUnplayedOnly: Bool = false
    @State private var localCurrentTime: TimeInterval = 0
    
    public init(bookId: UUID) {
        self.bookId = bookId
    }
    
    private var book: Book? {
        library.books.first(where: { $0.id == bookId })
    }
    
    private var filteredChapters: [Chapter] {
        guard let book = book else { return [] }
        var list = book.chapters
        if filterUnplayedOnly {
            list = list.filter { !$0.isCompleted }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }
    
    public var body: some View {
        Group {
            if let book = book {
                VStack(spacing: 0) {
                    // Player Control Card at top
                    playerCard(for: book)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    // Search & Filter header
                    searchAndFilterSection(for: book)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    // Chapter List
                    chapterListView(for: book)
                }
                .navigationTitle(book.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await library.refreshBook(book)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            } else {
                Text("Book not found")
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()) // slate-900
        .onReceive(player.$currentTime) { time in
            if player.currentBook?.id == bookId {
                localCurrentTime = time
            }
        }
    }
    
    // MARK: - Now Playing Card
    @ViewBuilder
    private func playerCard(for book: Book) -> some View {
        let isThisBookPlaying = player.currentBook?.id == book.id
        let activeChapter = isThisBookPlaying ? player.currentChapter : book.currentChapter
        
        VStack(spacing: 14) {
            // Chapter info
            VStack(alignment: .leading, spacing: 4) {
                Text(activeChapter?.title ?? "No Chapter Selected")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    if let chapter = activeChapter {
                        Text("Chapter Progress: \(Int(chapter.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let book = self.book {
                        Text("\(book.completedChaptersCount) / \(book.chapters.count) Done")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Scrubber
            ScrubberBar(
                currentTime: $localCurrentTime,
                duration: isThisBookPlaying ? player.duration : (activeChapter?.duration ?? 0),
                onScrubEnd: { newTime in
                    if isThisBookPlaying {
                        player.seek(to: newTime)
                    } else if let chapter = activeChapter {
                        player.playChapter(chapter, in: book, startPosition: newTime)
                    }
                }
            )
            
            // Main Controls
            HStack(spacing: 24) {
                // -15s
                Button {
                    player.skip(seconds: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Previous Chapter
                Button {
                    player.playPreviousChapter()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Play / Pause
                Button {
                    if isThisBookPlaying {
                        player.togglePlayPause()
                    } else if let ch = activeChapter {
                        player.playChapter(ch, in: book)
                    }
                } label: {
                    Image(systemName: (isThisBookPlaying && player.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(.green)
                }
                
                // Next Chapter
                Button {
                    player.playNextChapter()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // +30s
                Button {
                    player.skip(seconds: 30)
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            // Bottom pills: Speed & Sleep Timer
            HStack {
                SpeedPicker(
                    currentSpeed: Binding(
                        get: { player.playbackRate },
                        set: { player.setPlaybackRate($0) }
                    ),
                    onChange: { speed in
                        player.setPlaybackRate(speed)
                    }
                )
                
                Spacer()
                
                SleepTimerPicker()
            }
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.16, blue: 0.23)) // slate-800
        .cornerRadius(16)
    }
    
    // MARK: - Search & Filters
    @ViewBuilder
    private func searchAndFilterSection(for book: Book) -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search chapters...", text: $searchText)
                        .foregroundColor(.white)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(red: 0.12, green: 0.16, blue: 0.23))
                .cornerRadius(10)
                
                // Filter unplayed toggle
                Button {
                    filterUnplayedOnly.toggle()
                } label: {
                    Text(filterUnplayedOnly ? "Unplayed" : "All")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(filterUnplayedOnly ? Color.green : Color(white: 0.2))
                        .foregroundColor(filterUnplayedOnly ? .black : .white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Chapter List
    @ViewBuilder
    private func chapterListView(for book: Book) -> some View {
        List {
            ForEach(filteredChapters) { chapter in
                let isCurrent = player.currentBook?.id == book.id && player.currentChapter?.id == chapter.id
                
                HStack(spacing: 12) {
                    // Completion toggle
                    Button {
                        library.markChapterCompleted(bookId: book.id, chapterId: chapter.id, completed: !chapter.isCompleted)
                    } label: {
                        Image(systemName: chapter.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(chapter.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Chapter title & details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(chapter.title)
                                .font(.body.weight(isCurrent ? .bold : .regular))
                                .foregroundColor(isCurrent ? .green : .white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(ScrubberBar.formatTimeString(chapter.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(white: 0.2))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(chapter.isCompleted ? Color.green : (isCurrent ? Color.green : Color.gray))
                                    .frame(width: max(0, geo.size.width * CGFloat(chapter.progress)), height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    player.playChapter(chapter, in: book)
                }
                .listRowBackground(isCurrent ? Color(red: 0.15, green: 0.22, blue: 0.3) : Color.clear)
                .listRowSeparatorTint(Color(white: 0.15))
            }
        }
        .listStyle(.plain)
        .refreshable {
            await library.refreshBook(book)
        }
    }
}
