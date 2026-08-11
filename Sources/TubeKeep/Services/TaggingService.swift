import Foundation

actor TaggingService {
    let predefinedTags = [
        "기술/IT", "음악", "게임", "뉴스/시사",
        "스포츠", "엔터테인먼트", "교육/강의",
        "요리/음식", "여행/일상", "과학",
    ]

    func classify(title: String, channel: String, openRouterAPIKey: String, geminiAPIKey: String) async -> String {
        AITaskTracker.shared.begin()
        defer { AITaskTracker.shared.end() }

        let steps: [LLMChainStep<String>] = [
            LLMChainStep(provider: "Gemini", isAvailable: !geminiAPIKey.isEmpty, validate: { self.predefinedTags.contains($0) }) {
                let prompt = """
                Classify the following YouTube video into exactly ONE category.
                Choose only from: \(self.predefinedTags.joined(separator: ", "))

                Title: \(title)
                Channel: \(channel)

                Return ONLY the category name, nothing else.
                """
                return try await GeminiService().query(prompt: prompt, apiKey: geminiAPIKey)
            },
            LLMChainStep(provider: "OpenRouter", isAvailable: !openRouterAPIKey.isEmpty, validate: { self.predefinedTags.contains($0) }) {
                let service = OpenRouterService()
                return try await service.classifyTag(title: title, channel: channel, apiKey: openRouterAPIKey)
            },
        ]

        log("[AI Fallback] 태깅 체인 실행 — \(title)")
        if let result = await LLMChainExecutor.run(steps) {
            log("[AI Fallback] \(result.provider) 태깅 성공: \(result.output) — \(title)")
            return result.output
        }

        // 3순위: 규칙 기반
        let fallback = autoClassify(title: title, channel: channel)
        log("[AI Fallback] 규칙 기반 태깅: \(fallback) — \(title)")
        return fallback
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }

    private func autoClassify(title: String, channel: String) -> String {
        let lowerTitle = title.lowercased()
        let lowerChannel = channel.lowercased()

        let rules: [(String, [String])] = [
            ("기술/IT", ["review", "tech", "apple", "microsoft", "google", "mac", "iphone", "ipad", "ios",
                         "리뷰", "테크", "기술", "개발", "프로그래밍", "코딩", "swift", "ai",
                         "9to5mac", "it", "전자기기", "갤럭시", "아이폰", "맥북"]),
            ("음악", ["music", "song", "album", "mv", "오디오", "music video", "official audio",
                      "노래", "음악", "가사", "lyrics", "cover", "remix", "live performance",
                      "k-pop", "kpop"]),
            ("게임", ["game", "gaming", "gameplay", "playthrough", "walkthrough",
                      "게임", "플레이", "롤", "로스트아크", "배그", "발로란트"]),
            ("뉴스/시사", ["news", "breaking", "kbs", "mbc", "sbs", "ytn", "연합뉴스",
                          "뉴스", "속보", "시사", "정치", "경제"]),
            ("스포츠", ["sports", "sport", "football", "soccer", "baseball", "basketball",
                        "스포츠", "축구", "야구", "농구", "하이라이트"]),
            ("엔터테인먼트", ["entertainment", "예능", "방송", "tv", "쇼", "프로그램",
                            "연예", "연예인", "영화", "드라마"]),
            ("교육/강의", ["tutorial", "course", "lecture", "lesson", "guide", "how to",
                          "강의", "교육", "배움", "학습", "튜토리얼"]),
            ("요리/음식", ["cook", "recipe", "food", "요리", "레시피", "음식", "먹방", "쿡방"]),
            ("여행/일상", ["travel", "vlog", "daily", "일상", "여행", "vlog"]),
            ("과학", ["science", "physics", "chemistry", "biology", "space", "과학", "물리", "화학", "생물"]),
        ]

        for (tag, keywords) in rules {
            for keyword in keywords {
                if lowerTitle.contains(keyword) || lowerChannel.contains(keyword) {
                    return tag
                }
            }
        }

        return "기타"
    }
}
