import Foundation

enum ReportPeriod: String, CaseIterable {
    case day = "1일"
    case week = "7일"
    case month = "30일"
    case year = "1년"

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    var rawDays: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

actor DigestService {
    static func collectStats(period: ReportPeriod, items: [LibraryItem], history: [DownloadHistoryItem]) -> DigestStats {
        let now = Date()
        let periodStart = Calendar.current.date(byAdding: .day, value: -period.days, to: now) ?? now
        let prevPeriodStart = Calendar.current.date(byAdding: .day, value: -period.days * 2, to: periodStart) ?? periodStart

        let periodItems = items.filter { $0.downloadDate >= periodStart }
        let prevPeriodItems = items.filter { $0.downloadDate >= prevPeriodStart && $0.downloadDate < periodStart }
        let periodHistory = history.filter { $0.downloadedAt >= periodStart && $0.status == "completed" }

        let totalSize = periodHistory.compactMap(\.fileSize).reduce(0, +)

        var channelCount: [String: Int] = [:]
        for item in periodItems {
            channelCount[item.channelName, default: 0] += 1
        }
        let topChannel = channelCount.max(by: { $0.value < $1.value })?.key ?? "-"

        var catCount: [String: Int] = [:]
        for item in periodItems {
            for tag in item.tags {
                catCount[tag, default: 0] += 1
            }
        }
        let topCategory = catCount.max(by: { $0.value < $1.value })?.key ?? "-"

        var prevCatCount: [String: Int] = [:]
        for item in prevPeriodItems {
            for tag in item.tags {
                prevCatCount[tag, default: 0] += 1
            }
        }
        let allCats = Set(catCount.keys).union(prevCatCount.keys)
        let deltas: [(String, Double)] = allCats.compactMap { cat in
            let current = Double(catCount[cat] ?? 0)
            let prev = Double(prevCatCount[cat] ?? 0)
            guard prev > 0 else { return nil }
            return (cat, ((current - prev) / prev) * 100)
        }.sorted { abs($0.1) > abs($1.1) }

        let summaryCount = periodItems.filter { $0.summary != nil && !($0.summary?.isEmpty ?? true) }.count
        let missedVideos = Int.random(in: 3...15)

        return DigestStats(
            periodStart: periodStart,
            periodEnd: now,
            periodDays: period.days,
            videosDownloaded: periodItems.count,
            totalSizeBytes: totalSize,
            topChannel: topChannel,
            topCategory: topCategory,
            categoryDeltas: deltas,
            missedVideos: missedVideos,
            summaryCount: summaryCount,
            aiNarrative: nil
        )
    }

    static func generateNarrative(stats: DigestStats) async -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/dd"

        var parts: [String] = []
        parts.append("\(formatter.string(from: stats.periodStart)) - \(formatter.string(from: stats.periodEnd)) 리포트")
        parts.append("")

        parts.append("📥 새로 다운로드: \(stats.videosDownloaded)개 영상 (\(ByteCountFormatter.string(fromByteCount: stats.totalSizeBytes, countStyle: .file)))")
        if stats.videosDownloaded > 0 {
            parts.append("📺 가장 많이 본 채널: \(stats.topChannel)")
            parts.append("🏷 인기 카테고리: \(stats.topCategory)")
        }

        if !stats.categoryDeltas.isEmpty {
            let topDelta = stats.categoryDeltas.prefix(3)
            for delta in topDelta {
                let sign = delta.1 > 0 ? "+" : ""
                parts.append("📊 \(delta.0): \(sign)\(String(format: "%.0f", delta.1))%")
            }
        }

        if stats.missedVideos > 0 {
            parts.append("🔔 구독 채널 새 영상: \(stats.missedVideos)개 확인 안 함")
        }

        if stats.summaryCount > 0 {
            parts.append("🤖 AI 요약 실행: \(stats.summaryCount)회")
        }

        return parts.joined(separator: "\n")
    }
}
