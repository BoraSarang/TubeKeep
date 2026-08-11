import Foundation

final class ChannelInsightService {
    static let shared = ChannelInsightService()

    private let cacheKeyPrefix = "channelInsight"
    private let cacheTTL: TimeInterval = 30 * 24 * 3600

    /// AI 주제 요약을 생성하기 위한 최소 보관 영상 수
    static let minimumVideosForAI = 10

    // MARK: - 통계 계산

    static func compute(channelId: String, items: [LibraryItem]) -> ChannelInsightStats {
        let channelItems = items.filter {
            $0.channelId == channelId && $0.trashedAt == nil
        }
        guard !channelItems.isEmpty else { return ChannelInsightStats() }

        var stats = ChannelInsightStats()
        stats.videoCount = channelItems.count

        var tagCounts: [String: Int] = [:]
        for item in channelItems {
            for tag in item.tags where !tag.isEmpty && tag != "기타" {
                tagCounts[tag, default: 0] += 1
            }
        }
        stats.tagCounts = tagCounts
        stats.topCategories = tagCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        let durations = channelItems.compactMap(\.duration).filter { $0 > 0 }
        if !durations.isEmpty {
            stats.averageDuration = durations.reduce(0, +) / durations.count
            stats.totalMinutes = durations.reduce(0, +) / 60
        }

        if let cached = ChannelDownloadCache.cachedVideos(channelId: channelId) {
            stats.hasViewData = true
            if let top = cached.max(by: { $0.viewCount < $1.viewCount }), top.viewCount > 0 {
                let title = channelItems.first(where: { $0.id == top.id })?.title ?? top.title
                stats.topViewedVideo = (title, top.viewCount)
            }
        }

        return stats
    }

    // MARK: - AI 주제 요약 (캐시 + 체인)

    func needsSubtitle(videoCount: Int) -> Bool {
        videoCount >= Self.minimumVideosForAI
    }

    func cachedSummary(channelId: String) -> String? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: channelId)),
              let entry = try? JSONDecoder().decode(ChannelInsightSummaryCache.self, from: data),
              Date().timeIntervalSince(entry.generatedAt) < cacheTTL
        else { return nil }
        #if DEBUG
        DebugLogManager.shared?.append("[ChannelInsight] 캐시 히트 — 채널: \(channelId)")
        #endif
        return entry.summary
    }

    func saveSummary(channelId: String, summary: String) {
        let entry = ChannelInsightSummaryCache(summary: summary, generatedAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: channelId))
    }

    func invalidateCache(channelId: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: channelId))
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }

    private func cacheKey(for channelId: String) -> String {
        "\(cacheKeyPrefix):\(channelId)"
    }

    // MARK: - 생성 (OpenRouter → Gemini 폴백)

    func summarize(channelId: String, channelName: String, stats: ChannelInsightStats, items: [LibraryItem]) async -> String? {
        let keys = Settings.loadAPIKeys()

        let tagNames: String
        if stats.topCategories.isEmpty {
            tagNames = "(분류 정보 없음)"
        } else {
            tagNames = stats.topCategories.map { "\($0.0) \($0.1)개" }.joined(separator: ", ")
        }

        let samples = items
            .filter { $0.channelId == channelId && $0.trashedAt == nil }
            .sorted { $0.downloadDate > $1.downloadDate }
            .prefix(5)

        var sampleText = ""
        for item in samples {
            var line = "- \(item.title)"
            if let summary = item.summary, !summary.isEmpty {
                line += " | 요약: \(summary.prefix(600))"
            }
            sampleText += line + "\n"
        }
        if sampleText.isEmpty {
            sampleText = "(샘플 데이터 없음)"
        }

        let prompt = """
        다음 YouTube 채널의 보관 영상 데이터를 분석해, 이 채널이 주로 어떤 내용을 다루는 채널인지 한국어로 한 문단(3~5문장)으로 소개해 주세요.

        채널명: \(channelName)
        보관 영상 수: \(stats.videoCount)개
        카테고리 분포: \(tagNames)

        최근 영상 샘플(제목 + 요약):
        \(sampleText)

        채널의 성격, 주로 다루는 주제, 시청자가 얻을 수 있는 가치를 자연스럽게 서술하세요. 모든 답변은 반드시 한국어로만 작성하세요.
        """

        let systemMessage = "당신은 YouTube 채널을 분석해 한국어로 소개하는 전문가입니다. 반드시 한국어로만 답하세요."

        let steps: [LLMChainStep<String>] = [
            LLMChainStep(provider: "OpenRouter", isAvailable: !keys.openRouter.isEmpty, validate: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                let text = try await OpenRouterService().chatCompletion(
                    prompt: prompt,
                    apiKey: keys.openRouter,
                    systemMessage: systemMessage
                )
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            },
            LLMChainStep(provider: "Gemini", isAvailable: !keys.gemini.isEmpty, validate: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                let text = try await GeminiService().query(prompt: prompt, apiKey: keys.gemini)
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            },
        ]

        if let result = await LLMChainExecutor.run(steps) {
            log("[ChannelInsight] ✅ \(result.provider) 생성 — 채널: \(channelId)")
            return result.output
        }
        return nil
    }
}