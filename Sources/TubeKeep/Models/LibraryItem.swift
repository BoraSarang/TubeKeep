import Foundation

struct LibraryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let channelId: String
    let channelName: String
    let thumbnailURL: String
    var filePath: String
    let downloadDate: Date
    let uploadDate: Date?
    let duration: Int?
    let channelUploadIndex: Int?
    var tags: [String]
    var summary: String?

    init(id: String, title: String, channelId: String, channelName: String, thumbnailURL: String, filePath: String, downloadDate: Date, uploadDate: Date?, duration: Int?, channelUploadIndex: Int?, tags: [String] = [], summary: String? = nil) {
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
    }

    func withChannelUploadIndex(_ index: Int) -> LibraryItem {
        LibraryItem(
            id: id, title: title, channelId: channelId, channelName: channelName,
            thumbnailURL: thumbnailURL, filePath: filePath, downloadDate: downloadDate,
            uploadDate: uploadDate, duration: duration, channelUploadIndex: index,
            tags: tags, summary: summary
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, title, channelId, channelName, thumbnailURL, filePath, downloadDate, uploadDate, duration, channelUploadIndex, tags, summary
    }
}

extension LibraryItem: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        channelId = try c.decode(String.self, forKey: .channelId)
        channelName = try c.decode(String.self, forKey: .channelName)
        thumbnailURL = try c.decode(String.self, forKey: .thumbnailURL)
        filePath = try c.decode(String.self, forKey: .filePath)
        downloadDate = try c.decode(Date.self, forKey: .downloadDate)
        uploadDate = try c.decodeIfPresent(Date.self, forKey: .uploadDate)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        channelUploadIndex = try c.decodeIfPresent(Int.self, forKey: .channelUploadIndex)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(channelId, forKey: .channelId)
        try c.encode(channelName, forKey: .channelName)
        try c.encode(thumbnailURL, forKey: .thumbnailURL)
        try c.encode(filePath, forKey: .filePath)
        try c.encode(downloadDate, forKey: .downloadDate)
        try c.encodeIfPresent(uploadDate, forKey: .uploadDate)
        try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(channelUploadIndex, forKey: .channelUploadIndex)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(summary, forKey: .summary)
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
