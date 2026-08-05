import Foundation
import AppKit

enum ProfileService {
    static func calculate(
        items: [LibraryItem],
        channels: [SubscribedChannel],
        history: [DownloadHistoryItem],
        diskUsage: Int64
    ) -> UserProfile {
        var profile = UserProfile()
        profile.totalVideos = items.count
        profile.totalChannels = Set(items.map(\.channelId)).count
        profile.totalStorageBytes = diskUsage

        var catCount: [String: Int] = [:]
        for item in items {
            for tag in item.tags {
                catCount[tag, default: 0] += 1
            }
        }
        let total = max(catCount.values.reduce(0, +), 1)
        profile.categoryDistribution = catCount
            .map { (category: $0.key, count: $0.value, percentage: Double($0.value) / Double(total) * 100) }
            .sorted { $0.percentage > $1.percentage }

        var channelCount: [String: Int] = [:]
        for item in items {
            channelCount[item.channelName, default: 0] += 1
        }
        profile.topChannels = channelCount
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5).map { $0 }

        let durations = items.compactMap(\.duration).filter { $0 > 0 }
        if !durations.isEmpty {
            profile.averageDuration = Double(durations.reduce(0, +)) / Double(durations.count)
        }

        var resCount: [Int: Int] = [:]
        for h in history where h.status == "completed" {
            if let res = h.resolution, res > 0 {
                resCount[res, default: 0] += 1
            }
        }
        profile.preferredResolution = resCount.max(by: { $0.value < $1.value })?.key ?? 0

        var hourCount: [Int: Int] = [:]
        for h in history where h.status == "completed" {
            let hour = Calendar.current.component(.hour, from: h.downloadedAt)
            hourCount[hour, default: 0] += 1
        }
        profile.downloadTimeHistogram = hourCount

        var weeklyCounts: [String: Int] = [:]
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var weekItems = 0
        var summarizedItems = 0
        for item in items {
            if item.downloadDate >= weekAgo { weekItems += 1 }
            for tag in item.tags {
                weeklyCounts[tag, default: 0] += 1
            }
            if item.summary != nil && !(item.summary?.isEmpty ?? true) {
                summarizedItems += 1
            }
        }
        profile.weeklyDownloadCounts = weeklyCounts
        profile.summaryUsageRate = items.isEmpty ? 0 : Double(summarizedItems) / Double(items.count)
        return profile
    }
}
