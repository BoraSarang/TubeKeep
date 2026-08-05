import Foundation

struct DigestStats: Equatable {
    var periodStart: Date
    var periodEnd: Date
    var periodDays: Int
    var videosDownloaded: Int
    var totalSizeBytes: Int64
    var topChannel: String
    var topCategory: String
    var categoryDeltas: [(String, Double)]
    var missedVideos: Int
    var summaryCount: Int
    var aiNarrative: String?

    static func == (lhs: DigestStats, rhs: DigestStats) -> Bool {
        lhs.periodStart == rhs.periodStart &&
        lhs.periodEnd == rhs.periodEnd &&
        lhs.periodDays == rhs.periodDays &&
        lhs.videosDownloaded == rhs.videosDownloaded &&
        lhs.totalSizeBytes == rhs.totalSizeBytes &&
        lhs.topChannel == rhs.topChannel &&
        lhs.topCategory == rhs.topCategory &&
        lhs.missedVideos == rhs.missedVideos &&
        lhs.summaryCount == rhs.summaryCount &&
        lhs.aiNarrative == rhs.aiNarrative
    }

    static func empty(periodDays: Int) -> DigestStats {
        DigestStats(
            periodStart: Date(),
            periodEnd: Date(),
            periodDays: periodDays,
            videosDownloaded: 0,
            totalSizeBytes: 0,
            topChannel: "-",
            topCategory: "-",
            categoryDeltas: [],
            missedVideos: 0,
            summaryCount: 0,
            aiNarrative: nil
        )
    }
}
