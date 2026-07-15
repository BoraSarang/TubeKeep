import Foundation

struct LibraryItem: Identifiable, Equatable, Codable {
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

    func withChannelUploadIndex(_ index: Int) -> LibraryItem {
        LibraryItem(
            id: id, title: title, channelId: channelId, channelName: channelName,
            thumbnailURL: thumbnailURL, filePath: filePath, downloadDate: downloadDate,
            uploadDate: uploadDate, duration: duration, channelUploadIndex: index
        )
    }

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
