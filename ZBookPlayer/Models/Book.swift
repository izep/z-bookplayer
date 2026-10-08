import Foundation

public struct Book: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var bookmarkData: Data
    public var coverImageFileName: String?
    public var chapters: [Chapter]
    public var lastPlayedChapterId: String?
    public var lastPlayedDate: Date?
    
    public init(
        id: UUID = UUID(),
        title: String,
        bookmarkData: Data,
        coverImageFileName: String? = nil,
        chapters: [Chapter] = [],
        lastPlayedChapterId: String? = nil,
        lastPlayedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.bookmarkData = bookmarkData
        self.coverImageFileName = coverImageFileName
        self.chapters = chapters
        self.lastPlayedChapterId = lastPlayedChapterId
        self.lastPlayedDate = lastPlayedDate
    }
    
    public var totalDuration: TimeInterval {
        chapters.reduce(0) { $0 + $1.duration }
    }
    
    public var totalListened: TimeInterval {
        chapters.reduce(0) { sum, ch in
            if ch.isCompleted {
                return sum + ch.duration
            }
            return sum + ch.currentTime
        }
    }
    
    public var completedChaptersCount: Int {
        chapters.filter { $0.isCompleted }.count
    }
    
    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(totalListened / totalDuration, 0), 1.0)
    }
    
    public var currentChapter: Chapter? {
        if let id = lastPlayedChapterId, let ch = chapters.first(where: { $0.id == id }) {
            return ch
        }
        return chapters.first(where: { !$0.isCompleted }) ?? chapters.first
    }
}
