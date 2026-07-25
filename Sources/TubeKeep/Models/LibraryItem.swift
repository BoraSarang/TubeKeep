import Foundation
import SwiftData

@Model
final class LibraryItem: Identifiable {
    @Attribute(.unique) var id: String
    var title: String
    var channelId: String
    var channelName: String
    var thumbnailURL: String
    var filePath: String
    var downloadDate: Date
    var uploadDate: Date?
    var duration: Int?
    var channelUploadIndex: Int?
    var tags: [String]
    var summary: String?

    // v2.5.0: AI 콘텐츠 캐싱
    var transcript: String?
    var chapters: Data?
    var subtitleLanguage: String?

    init(id: String, title: String, channelId: String, channelName: String, thumbnailURL: String, filePath: String, downloadDate: Date, uploadDate: Date?, duration: Int?, channelUploadIndex: Int?, tags: [String] = [], summary: String? = nil, transcript: String? = nil, chapters: Data? = nil, subtitleLanguage: String? = nil) {
        self.id = id
        self.title = title
        self.channelId = channelId
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.filePath = filePath
        self.downloadDate = downloadDate
        self.uploadDate = uploadDate
        self.duration = duration
        self.channelUploadIndex = channelUploadIndex
        self.tags = tags
        self.summary = summary
        self.transcript = transcript
        self.chapters = chapters
        self.subtitleLanguage = subtitleLanguage
    }

    func withChannelUploadIndex(_ index: Int) -> LibraryItem {
        let item = LibraryItem(
            id: id, title: title, channelId: channelId, channelName: channelName,
            thumbnailURL: thumbnailURL, filePath: filePath, downloadDate: downloadDate,
            uploadDate: uploadDate, duration: duration, channelUploadIndex: index,
            tags: tags, summary: summary, transcript: transcript, chapters: chapters,
            subtitleLanguage: subtitleLanguage
        )
        return item
    }
}

extension LibraryItem: @unchecked Sendable {}

extension LibraryItem: Equatable {
    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension LibraryItem {
    static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

private let uploadDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd"
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}()

extension LibraryItem {
    static func parseUploadDate(_ yyyyMMdd: String) -> Date? {
        uploadDateFormatter.date(from: yyyyMMdd)
    }
}

enum LibrarySortOrder: String, Equatable, CaseIterable {
    case dateDesc = "최신순"
    case dateAsc = "오래된순"
    case titleAsc = "제목순"
    case channelAsc = "채널순"
    case uploadDateDesc = "업로드순 (최신)"
    case uploadDateAsc = "업로드순 (오래된)"
    case indexAsc = "인덱스순"
    case indexDesc = "인덱스 역순"
}

enum LibraryFilterMode: Equatable {
    case all
    case recent
}

enum LibraryViewMode: String, Equatable, CaseIterable {
    case grid = "그리드"
    case list = "목록"
}
