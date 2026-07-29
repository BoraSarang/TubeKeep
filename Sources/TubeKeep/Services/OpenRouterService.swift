import Foundation

enum OpenRouterError: LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case decodingFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "OpenRouter API 키가 없습니다. 설정에서 API 키를 입력해 주세요."
        case let .apiError(msg): return "OpenRouter API 오류: \(msg)"
        case .decodingFailed: return "OpenRouter 응답 해석 실패"
        case let .networkError(err): return "OpenRouter 네트워크 오류: \(err.localizedDescription)"
        }
    }
}

struct OpenRouterService {
    private let baseURL = "https://openrouter.ai/api/v1"

    func generateSummary(
        transcript: String,
        title: String,
        channel: String,
        apiKey: String
    ) async throws -> (overview: String, keyPoints: [String], chapters: [ChapterInfo]) {
        let prompt = """
        다음 YouTube 영상의 자막을 분석하여 요약해 주세요.

        **반드시 모든 내용을 한국어로 답변하세요. 영어 사용 금지.**

        제목: \(title)
        채널: \(channel)

        자막 내용:
        \(transcript.prefix(15000))

        아래 정확한 형식으로 답변하세요:

        개요: (2~3문장 요약)

        핵심 포인트:
        • (핵심 포인트 1)
        • (핵심 포인트 2)
        • (핵심 포인트 3)

        챕터:
        • [0:00 - 2:30] 챕터 제목
        • [2:30 - 5:00] 챕터 제목

        챕터는 영상의 주요 내용 구간을 2~5개로 나누어 시간대와 함께 작성하세요.
        """

        let response = try await chatCompletion(
            messages: [
                ["role": "system", "content": "당신은 YouTube 영상 요약 전문가입니다. 반드시 한국어로만 답변하세요. 영어를 사용하지 마세요."],
                ["role": "user", "content": prompt]
            ],
            apiKey: apiKey
        )

        return parseSummaryResponse(response)
    }

    func classifyTag(
        title: String,
        channel: String,
        apiKey: String
    ) async throws -> String {
        let predefinedTags = [
            "기술/IT", "음악", "게임", "뉴스/시사",
            "스포츠", "엔터테인먼트", "교육/강의",
            "요리/음식", "여행/일상", "과학",
        ]

        let prompt = """
        다음 YouTube 영상의 제목과 채널명을 보고 가장 적합한 태그를 선택해 주세요.

        제목: \(title)
        채널: \(channel)

        다음 태그 중 하나만 선택해 주세요: \(predefinedTags.joined(separator: ", "))

        답변은 선택된 태그 이름만 작성해 주세요. 다른 텍스트는 포함하지 마세요.
        """

        let response = try await chatCompletion(
            messages: [
                ["role": "system", "content": "당신은 YouTube 영상 분류 전문가입니다. 주어진 제목과 채널명을 분석하여 가장 적합한 카테고리를 선택합니다."],
                ["role": "user", "content": prompt]
            ],
            apiKey: apiKey
        )

        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")

        if predefinedTags.contains(cleaned) {
            return cleaned
        }

        let matched = predefinedTags.first { tag in
            cleaned.localizedCaseInsensitiveContains(tag) ||
            tag.localizedCaseInsensitiveContains(cleaned)
        }
        return matched ?? "기타"
    }

    // MARK: - Public Chat Completion

    func chatCompletion(
        prompt: String,
        apiKey: String,
        systemMessage: String = "당신은 한국어로 답변하는 전문가입니다."
    ) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "system", "content": systemMessage],
            ["role": "user", "content": prompt]
        ]
        return try await chatCompletion(messages: messages, apiKey: apiKey)
    }

    // MARK: - Private

    private func chatCompletion(
        messages: [[String: String]],
        apiKey: String
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenRouterError.invalidAPIKey
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenRouterError.decodingFailed
        }

        let userModel = UserDefaults.standard.string(forKey: "openRouterModel") ?? Constants.defaultOpenRouterModel

        // 1차: 사용자 지정 모델로 요청
        log("[OpenRouter] 요청 시작 — 모델: \(userModel)")
        if let result = try? await sendRequest(url: url, apiKey: apiKey, model: userModel, messages: messages) {
            return result
        }

        // 2차: 429 에러 시 openrouter/free로 폴백
        if userModel != Constants.defaultOpenRouterModel {
            log("[OpenRouter] 모델 \(userModel) 실패 → openrouter/free로 폴백")
            if let result = try? await sendRequest(url: url, apiKey: apiKey, model: Constants.defaultOpenRouterModel, messages: messages) {
                log("[OpenRouter] openrouter/free 폴백 성공")
                return result
            }
        }

        throw OpenRouterError.apiError("모든 OpenRouter 모델을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.")
    }

    private func sendRequest(
        url: URL,
        apiKey: String,
        model: String,
        messages: [[String: String]],
        timeout: TimeInterval = 45
    ) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("TubeKeep", forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = timeout

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 4096
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }

        let responseStr = String(data: data, encoding: .utf8) ?? ""
        log("[OpenRouter] 모델 \(model) — HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            log("[OpenRouter] 모델 \(model) 실패 — \(responseStr.prefix(200))")
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(OpenRouterChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content, !content.isEmpty else {
            log("[OpenRouter] 모델 \(model) 디코딩 실패")
            return nil
        }

        log("[OpenRouter] 모델 \(model) 성공 — 응답 길이: \(content.count)")
        return content
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }

    func chatCompletionForPodcast(
        prompt: String,
        apiKey: String
    ) async throws -> String {
        let podcastModels = [
            "nvidia/nemotron-3-super-120b-a12b:free",
            "google/gemma-4-31b-it:free",
            "meta-llama/llama-3.3-70b-instruct:free",
            "qwen/qwen3-235b-a22b:free",
            "openrouter/free"
        ]

        for model in podcastModels {
            log("[OpenRouter] 팟캐스트 모델 시도 — \(model)")
            guard let url = URL(string: "\(baseURL)/chat/completions") else { continue }

            let messages: [[String: String]] = [
                ["role": "system", "content": "당신은 한국어 팟캐스트 대화 스크립트 전문가입니다. 반드시 모든 출력은 한국어로만 작성하세요. 영어 단어를 절대 사용하지 마세요. 반드시 JSON 배열만 출력하세요. 다른 텍스트를 포함하지 마세요."],
                ["role": "user", "content": prompt + "\n\n[중요] 반드시 한국어로만 답변하세요. 반드시 JSON 배열 [{\"speaker\":\"진행자A\",\"text\":\"...\"}] 형식만 출력하세요. 다른 설명 없이 JSON만 출력하세요."]
            ]

            if let result = try? await sendRequest(url: url, apiKey: apiKey, model: model, messages: messages) {
                let isEnglish = isMostlyEnglish(result)
                if isEnglish {
                    log("[OpenRouter] \(model) 영문 응답 감지 → 다음 모델 시도")
                    continue
                }
                if result.count < 200 {
                    log("[OpenRouter] \(model) 응답 너무 짧음(\(result.count)자) → 다음 모델 시도")
                    continue
                }
                log("[OpenRouter] 팟캐스트 모델 성공 — \(model)")
                return result
            }
        }

        throw OpenRouterError.apiError("팟캐스트 생성 실패 — 한국어 응답을 받지 못했습니다.")
    }

    private func isMostlyEnglish(_ text: String) -> Bool {
        let koreanChars = text.unicodeScalars.filter { (0xAC00...0xD7AF).contains($0.value) }.count
        let totalLetters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard totalLetters > 20 else { return false }
        return Double(koreanChars) / Double(totalLetters) < 0.2
    }

    private func parseSummaryResponse(_ response: String) -> (overview: String, keyPoints: [String], chapters: [ChapterInfo]) {
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var overview = ""
        var keyPoints: [String] = []
        var chapters: [ChapterInfo] = []
        var inKeyPoints = false
        var inChapters = false

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("개요") || lower.contains("overview") {
                inKeyPoints = false
                inChapters = false
                continue
            }
            if lower.contains("핵심") || lower.contains("key point") {
                inKeyPoints = true
                inChapters = false
                continue
            }
            if lower.contains("챕터") || lower.contains("chapter") {
                inKeyPoints = false
                inChapters = true
                continue
            }

            if inKeyPoints {
                let cleaned = line
                    .replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    keyPoints.append(cleaned)
                }
            } else if inChapters {
                if let chapter = SummarizationService.parseChapterLineStatic(line) {
                    chapters.append(chapter)
                }
            } else if !overview.isEmpty {
                overview += " " + line
            } else {
                overview = line
                    .replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        if overview.isEmpty && !lines.isEmpty {
            overview = lines[0]
        }

        return (overview, Array(keyPoints.prefix(5)), chapters)
    }
}

private struct OpenRouterChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
