import Foundation

struct TrendingVideo: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let channel: String
    let channelId: String
    let viewCount: Int?
    let duration: Int?
    let uploadDate: String?
    let thumbnailURL: String
    let webpageURL: String

    var formattedViews: String {
        guard let count = viewCount else { return "" }
        if count >= 1_000_000 {
            return "\(String(format: "%.1f", Double(count) / 1_000_000))M"
        } else if count >= 1_000 {
            return "\(String(format: "%.1f", Double(count) / 1_000))K"
        }
        return "\(count)"
    }

    var formattedDuration: String {
        guard let seconds = duration, seconds > 0 else { return "" }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

enum TrendingCategory: String, Equatable, CaseIterable {
    case all = "전체"
    case music = "음악"
    case technology = "기술"
    case gaming = "게임"
    case news = "뉴스"
    case sports = "스포츠"
    case entertainment = "엔터테인먼트"
    case education = "교육"

    var systemIcon: String {
        switch self {
        case .all: return "flame"
        case .music: return "music.note"
        case .technology: return "desktopcomputer"
        case .gaming: return "gamecontroller"
        case .news: return "newspaper"
        case .sports: return "sportscourt"
        case .entertainment: return "film"
        case .education: return "book"
        }
    }

    var searchQuery: String {
        switch self {
        case .all: return "오늘 인기 영상"
        case .music: return "최신 음악"
        case .technology: return "최신 기술 리뷰"
        case .gaming: return "최신 게임"
        case .news: return "오늘 뉴스"
        case .sports: return "스포츠 하이라이트"
        case .entertainment: return "연예"
        case .education: return "교육 강의"
        }
    }
}
