import Foundation

struct LibraryItem: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let channelId: String
    let channelName: String
    let thumbnailURL: String
    let filePath: String
    let downloadDate: Date
}

enum LibrarySortOrder: String, Equatable, CaseIterable {
    case dateDesc = "최신순"
    case dateAsc = "오래된순"
    case titleAsc = "제목순"
    case channelAsc = "채널순"
}

enum LibraryFilterMode: Equatable {
    case all
    case recent
}

enum LibraryViewMode: String, Equatable, CaseIterable {
    case grid = "그리드"
    case list = "목록"
}
