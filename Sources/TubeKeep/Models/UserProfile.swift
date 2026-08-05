import Foundation

struct UserProfile: Equatable {
    var totalVideos: Int = 0
    var totalChannels: Int = 0
    var totalStorageBytes: Int64 = 0
    var categoryDistribution: [(category: String, count: Int, percentage: Double)] = []
    var topChannels: [(name: String, count: Int)] = []
    var averageDuration: TimeInterval = 0
    var preferredResolution: Int = 0
    var downloadTimeHistogram: [Int: Int] = [:]
    var weeklyDownloadCounts: [String: Int] = [:]
    var summaryUsageRate: Double = 0

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.totalVideos == rhs.totalVideos &&
        lhs.totalChannels == rhs.totalChannels &&
        lhs.totalStorageBytes == rhs.totalStorageBytes &&
        lhs.categoryDistribution.map { $0.category } == rhs.categoryDistribution.map { $0.category } &&
        lhs.topChannels.map { $0.name } == rhs.topChannels.map { $0.name } &&
        lhs.averageDuration == rhs.averageDuration &&
        lhs.preferredResolution == rhs.preferredResolution &&
        lhs.downloadTimeHistogram == rhs.downloadTimeHistogram &&
        lhs.weeklyDownloadCounts == rhs.weeklyDownloadCounts &&
        lhs.summaryUsageRate == rhs.summaryUsageRate
    }
}
