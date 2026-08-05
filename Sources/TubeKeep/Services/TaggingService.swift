import Foundation

actor TaggingService {
    let predefinedTags = [
        "기술/IT", "음악", "게임", "뉴스/시사",
        "스포츠", "엔터테인먼트", "교육/강의",
        "요리/음식", "여행/일상", "과학",
    ]

    func classify(title: String, channel: String, openRouterAPIKey: String, ax4APIKey: String, geminiAPIKey: String) async -> String {
        // 1순위: OpenRouter (무료)
        if !openRouterAPIKey.isEmpty {
            do {
                let service = OpenRouterService()
                let tag = try await service.classifyTag(title: title, channel: channel, apiKey: openRouterAPIKey)
                if predefinedTags.contains(tag) {
                    log("[AI Fallback] OpenRouter 태깅 성공: \(tag) — \(title)")
                    return tag
                }
                log("[AI Fallback] OpenRouter 태깅 결과 미매칭(\(tag)) → A.X 4.0 시도 — \(title)")
            } catch {
                log("[AI Fallback] OpenRouter 태깅 실패(\(error.localizedDescription)) → A.X 4.0 시도 — \(title)")
            }
        } else {
            log("[AI Fallback] OpenRouter 키 없음 → A.X 4.0 시도 — \(title)")
        }

        // 2순위: A.X 4.0
        if !ax4APIKey.isEmpty {
            do {
                let tag = try await classifyWithAX4(title: title, channel: channel, apiKey: ax4APIKey)
                if predefinedTags.contains(tag) {
                    log("[AI Fallback] A.X 4.0 태깅 성공: \(tag) — \(title)")
                    return tag
                }
                log("[AI Fallback] A.X 4.0 태깅 결과 미매칭(\(tag)) → Gemini 시도 — \(title)")
            } catch AX4Error.serviceUnavailable {
                log("[AI Fallback] A.X 4.0 게스트 API 종료 → Gemini 시도 — \(title)")
            } catch {
                log("[AI Fallback] A.X 4.0 태깅 실패 → Gemini 시도 — \(title)")
            }
        } else {
            log("[AI Fallback] A.X 4.0 키 없음 → Gemini 시도 — \(title)")
        }

        // 3순위: Gemini (유료)
        if !geminiAPIKey.isEmpty {
            let prompt = """
            Classify the following YouTube video into exactly ONE category.
            Choose only from: \(predefinedTags.joined(separator: ", "))

            Title: \(title)
            Channel: \(channel)

            Return ONLY the category name, nothing else.
            """
            if let tag = try? await GeminiService().query(prompt: prompt, apiKey: geminiAPIKey),
               predefinedTags.contains(tag) {
                log("[AI Fallback] Gemini 태깅 성공: \(tag) — \(title)")
                return tag
            }
            log("[AI Fallback] Gemini 태깅 실패 → 규칙 기반 분류 — \(title)")
        } else {
            log("[AI Fallback] Gemini 키 없음 → 규칙 기반 분류 — \(title)")
        }

        // 4순위: 규칙 기반
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

    private func classifyWithAX4(title: String, channel: String, apiKey: String) async throws -> String {
        let ax4 = AX4Service()
        return try await ax4.classifyTag(title: title, channel: channel, apiKey: apiKey)
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
