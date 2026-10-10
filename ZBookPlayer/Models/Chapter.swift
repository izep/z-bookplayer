import Foundation

public struct Chapter: Identifiable, Codable, Equatable, Hashable {
    public let id: String // Unique identifier (typically the relative file name)
    public let fileName: String
    public let title: String
    public let chapterNumber: Double?
    public var duration: TimeInterval
    public var currentTime: TimeInterval
    public var isCompleted: Bool
    
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1.0)
    }
    
    public var volumeName: String?
    public var volumeOrder: Double?
    public var volumeCoverFileName: String?
    
    public init(
        fileName: String,
        title: String,
        chapterNumber: Double? = nil,
        duration: TimeInterval = 0,
        currentTime: TimeInterval = 0,
        isCompleted: Bool = false,
        volumeName: String? = nil,
        volumeOrder: Double? = nil,
        volumeCoverFileName: String? = nil
    ) {
        self.id = fileName
        self.fileName = fileName
        self.title = title
        self.chapterNumber = chapterNumber ?? Chapter.parseChapterNumber(from: title.isEmpty ? fileName : title)
        self.duration = duration
        self.currentTime = currentTime
        self.isCompleted = isCompleted
        self.volumeName = volumeName
        self.volumeOrder = volumeOrder
        self.volumeCoverFileName = volumeCoverFileName
    }
    
    public static func parseChapterNumber(from string: String) -> Double? {
        // Match patterns like "Chapter 203", "Ch. 203.5", "Ch 203", "c203", or leading digits "203 - "
        let pattern = #"(?:chapter|ch\.?|ep\.?|episode|c)?\s*([0-9]+(?:\.[0-9]+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = string as NSString
            let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let numStr = nsString.substring(with: range)
                    if let val = Double(numStr) {
                        return val
                    }
                }
            }
        }
        return nil
    }
    
    public static func naturalSortCompare(lhs: Chapter, rhs: Chapter) -> Bool {
        // 1. Sort by volume order if available
        if let lVol = lhs.volumeOrder, let rVol = rhs.volumeOrder, lVol != rVol {
            return lVol < rVol
        }
        if lhs.volumeOrder != nil && rhs.volumeOrder == nil {
            return false
        }
        if lhs.volumeOrder == nil && rhs.volumeOrder != nil {
            return true
        }
        
        // 2. Sort by chapter number
        if let lNum = lhs.chapterNumber, let rNum = rhs.chapterNumber, lNum != rNum {
            return lNum < rNum
        }
        
        return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
    }
}
