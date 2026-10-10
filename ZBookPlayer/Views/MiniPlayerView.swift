import SwiftUI

public struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayer.shared
    public let onTap: () -> Void
    
    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }
    
    public var body: some View {
        if let chapter = player.currentChapter, let book = player.currentBook {
            HStack(spacing: 12) {
                // Book cover thumbnail or placeholder
                miniCoverThumbnail(for: book)
                
                // Chapter & Book Titles
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(book.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play / Pause
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                
                // Skip 30s
                Button {
                    player.skip(seconds: 30)
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.12, green: 0.16, blue: 0.23).opacity(0.95))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
    
    @ViewBuilder
    private func miniCoverThumbnail(for book: Book) -> some View {
        if let image = LibraryManager.shared.coverImage(for: book) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.2))
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.green)
            }
            .frame(width: 42, height: 42)
        }
    }
}
