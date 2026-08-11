import Foundation

/// 재생 중인 영상 기반으로 "비슷한 영상"을 실제 유튜브에서 검색하는 서비스.
/// - 검색어 생성: OpenRouter → Gemini → 규칙 폴백 (AI 실패/키 없어도 동작)
/// - 캐시: UserDefaults `similarQueriesCache` (videoId별, TTL 7일)
/// - 검색: 기존 `TrendingService.search`(yt-dlp `ytsearch`) 3쿼리 병렬 호출 → 병합·중복 제거
actor SimilarVideoService {
    static let shared = SimilarVideoService()

    private let trending = TrendingService()
    private let cacheKey = "similarQueriesCache"
    private static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    struct QueriesCacheEntry: Codable {
        let queries: [String]
        let timestamp: Date

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < SimilarVideoService.cacheTTL
        }
    }

    // MARK: - Public

    /// 영상 정보를 바탕으로 한글 검색어 3~4개 생성 (캐시 히트 시 캐시 반환).
    func generateQueries(videoId: String, title: String, channel: String, tags: [String], summary: String?, keys: Settings.APIKeys) async -> [String] {
        if let cached = cachedQueries(for: videoId), !cached.isEmpty {
            #if DEBUG
            log("[Similar] 캐시 히트 — \(videoId): \(cached)")
            #endif
            return cached
        }

        let aiQueries = await buildQueriesFromAI(
            title: title, channel: channel, tags: tags, summary: summary,
            openRouterKey: keys.openRouter, geminiKey: keys.gemini
        )
        let queries = aiQueries ?? buildQueriesFromRules(title: title, channel: channel, tags: tags)
        let unique = dedupe(queries)

        if !unique.isEmpty {
            saveCachedQueries(unique, for: videoId)
            #if DEBUG
            log("[Similar] 검색어 생성 완료 — \(videoId): \(unique)")
            #endif
        }
        return unique
    }

    /// 검색어로 실제 유튜브 검색 후 병합·현재 영상 제외.
    func searchSimilar(videoId: String, queries: [String]) async throws -> [TrendingVideo] {
        let limited = Array(queries.prefix(3))
        guard !limited.isEmpty else { return [] }

        var results: [[TrendingVideo]] = []
        do {
            results = try await withThrowingTaskGroup(of: [TrendingVideo].self) { group in
                for query in limited {
                    group.addTask { [trending] in
                        (try? await trending.search(query: query, maxResults: 10)) ?? []
                    }
                }
                var all: [[TrendingVideo]] = []
                for try await batch in group { all.append(batch) }
                return all
            }
        } catch {
            throw error
        }

        var seen = Set<String>()
        var merged: [TrendingVideo] = []
        for batch in results {
            for video in batch {
                guard video.id != videoId, !seen.contains(video.id) else { continue }
                seen.insert(video.id)
                merged.append(video)
                if merged.count >= 12 { break }
            }
            if merged.count >= 12 { break }
        }
        return merged
    }

    // MARK: - AI 검색어 생성

    private func buildQueriesFromAI(title: String, channel: String, tags: [String], summary: String?, openRouterKey: String, geminiKey: String) async -> [String]? {
        let prompt = """
        다음 YouTube 영상과 관련성이 높은 유튜브 검색어를 한국어로 3~4개 생성해 주세요.

        제목: \(title)
        채널: \(channel)
        \(tags.isEmpty ? "" : "카테고리: \(tags.joined(separator: ", "))")
        \(summary.map { "요약: \($0.prefix(500))" } ?? "")

        규칙:
        - 영상의 핵심 주제를 정확히 담은 검색어 (일반적이지 않은 구체적인 단어 사용)
        - 한국어로 작성. 제목이 외국어면 제목을 살린 한국어 검색어도 함께 생성.
        - 유튜브에서 유사한 콘텐츠가 잘 나오도록 자연스러운 검색어.
        - 반드시 JSON 문자열 배열 형태로만 출력하세요. 예: ["검색어1", "검색어2", "검색어3"] 다른 텍스트 금지.
        """

        if !openRouterKey.isEmpty || !geminiKey.isEmpty {
            let openRouterSystem = "당신은 한국어로 답변하는 YouTube 추천 전문가입니다. 반드시 한국어로만 답변하고 JSON 배열만 출력하세요."
            let geminiPrompt = prompt + "\n\n반드시 JSON 배열만 출력하세요."

            let steps: [LLMChainStep<[String]>] = [
                LLMChainStep(provider: "OpenRouter", isAvailable: !openRouterKey.isEmpty, validate: { !$0.isEmpty }) {
                    let service = OpenRouterService()
                    let response = try await service.chatCompletion(
                        prompt: prompt,
                        apiKey: openRouterKey,
                        systemMessage: openRouterSystem
                    )
                    guard let queries = self.parseQueries(from: response), !queries.isEmpty else {
                        throw LLMChainStepError.invalidOutput
                    }
                    return queries
                },
                LLMChainStep(provider: "Gemini", isAvailable: !geminiKey.isEmpty, validate: { !$0.isEmpty }) {
                    let response = try await GeminiService().query(prompt: geminiPrompt, apiKey: geminiKey)
                    guard let queries = self.parseQueries(from: response), !queries.isEmpty else {
                        throw LLMChainStepError.invalidOutput
                    }
                    return queries
                },
            ]

            if let result = await LLMChainExecutor.run(steps) {
                log("[Similar] \(result.provider) 검색어 생성 성공: \(result.output)")
                return result.output
            }
        }

        return nil
    }

    /// AI 응답(JSON 배열 또는 줄 단위)에서 검색어 추출.
    private func parseQueries(from response: String) -> [String]? {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: #"```(?:json)?"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // JSON 배열 파싱 시도
        if cleaned.hasPrefix("[") {
            if let data = cleaned.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                return array.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
        }

        // 줄 단위/불릿/쉼표 분리 폴백
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.replacingOccurrences(of: #"^[-•*\d\.\)]+\s*"#, with: "", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "[" && $0 != "]" }
        let queries = lines.flatMap { line -> [String] in
            if line.contains(",") {
                return line.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            return [line]
        }
        .filter { !$0.hasPrefix("[") && !$0.hasSuffix("]") }
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "[]\"")) }
        .filter { !$0.isEmpty }

        return queries.isEmpty ? nil : queries
    }

    // MARK: - 규칙 폴백

    private func buildQueriesFromRules(title: String, channel: String, tags: [String]) -> [String] {
        var queries: [String] = []

        if !title.isEmpty {
            queries.append(title)
        }
        if !channel.isEmpty {
            queries.append(channel)
        }
        if let tag = tags.first, !tag.isEmpty, tag != "기타" {
            queries.append(tag)
        }
        if !title.isEmpty && !channel.isEmpty {
            queries.append("\(title) \(channel)")
        }

        return Array(dedupe(queries).prefix(4))
    }

    // MARK: - 캐시

    private func cachedQueries(for videoId: String) -> [String]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: QueriesCacheEntry].self, from: data),
              let entry = dict[videoId],
              entry.isValid
        else { return nil }
        return entry.queries
    }

    private func saveCachedQueries(_ queries: [String], for videoId: String) {
        var dict: [String: QueriesCacheEntry] = [:]
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let existing = try? JSONDecoder().decode([String: QueriesCacheEntry].self, from: data) {
            dict = existing
        }
        dict[videoId] = QueriesCacheEntry(queries: queries, timestamp: Date())
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func dedupe(_ queries: [String]) -> [String] {
        var seen = Set<String>()
        return queries.filter { query in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return false }
            seen.insert(trimmed)
            return true
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
