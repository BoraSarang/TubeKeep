import Foundation

struct ChannelInsightStats {
    var videoCount: Int = 0
    var tagCounts: [String: Int] = [:]
    var averageDuration: Int = 0
    var totalMinutes: Int = 0
    var topCategories: [(String, Int)] = []
    var topViewedVideo: (title: String, viewCount: Int)?
    var hasViewData: Bool = false
}

struct ChannelInsightSummaryCache: Codable {
    let summary: String
    let generatedAt: Date
}