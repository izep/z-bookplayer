import SwiftUI
import UniformTypeIdentifiers

public struct BookshelfView: View {
    @ObservedObject var library = LibraryManager.shared
    @ObservedObject var player = AudioPlayer.shared
    
    @State private var showFolderPicker: Bool = false
    @State private var selectedBookForNavigation: Book? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(red: 0.06, green: 0.09, blue: 0.16) // slate-900
                    .ignoresSafeArea()
                
                if library.books.isEmpty {
                    emptyStateView
                } else {
                    bookListView
                }
                
                // Docked MiniPlayer when a book/chapter is playing or paused
                if player.currentChapter != nil {
                    MiniPlayerView {
                        if let book = player.currentBook {
                            selectedBookForNavigation = book
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Z-BookPlayer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFolderPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text("Add Folder")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let folderURL = urls.first {
                        Task {
                            await library.addBook(from: folderURL)
                        }
                    }
                case .failure(let error):
                    print("Folder picker failed: \(error.localizedDescription)")
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(bookId: book.id)
            }
            .navigationDestination(item: $selectedBookForNavigation) { book in
                BookDetailView(bookId: book.id)
            }
            .alert("Error", isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.errorMessage = nil } }
            )) {
                Button("OK") { library.errorMessage = nil }
            } message: {
                Text(library.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 64))
                .foregroundColor(.green.opacity(0.8))
            
            Text("No Audiobooks Added")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text("Tap '+ Add Folder' above and select an iCloud Drive folder (like '1% Lifesteal - Audio' or 'HDT - Audio').")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showFolderPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Select Book Folder")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Book List View
    private var bookListView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(library.books) { book in
                    NavigationLink(value: book) {
                        bookCard(for: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            Task { await library.refreshBook(book) }
                        } label: {
                            Label("Scan for New Chapters", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            library.deleteBook(book)
                        } label: {
                            Label("Remove from Library", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, player.currentChapter != nil ? 80 : 20)
        }
        .refreshable {
            await library.refreshAllBooks()
        }
    }
    
    // MARK: - Book Card
    private func bookCard(for book: Book) -> some View {
        HStack(spacing: 16) {
            // Book cover / Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.18))
                Image(systemName: "headphones")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }
            .frame(width: 72, height: 72)
            
            // Book information
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(book.chapters.count) chapters")
                    Text("•")
                    Text(ScrubberBar.formatTimeString(book.totalDuration))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(white: 0.2))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.green)
                                .frame(width: max(0, geo.size.width * CGFloat(book.progress)), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        Text("\(Int(book.progress * 100))% complete")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(book.completedChaptersCount) / \(book.chapters.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.16, blue: 0.23)) // slate-800
        .cornerRadius(16)
    }
}
