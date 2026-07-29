import Foundation

enum AX4Error: LocalizedError {
    case invalidResponse
    case decodingFailed
    case apiError(String)
    case serviceUnavailable
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "A.X 4.0 응답이 없습니다"
        case .decodingFailed: return "A.X 4.0 응답 해석 실패"
        case .apiError(let msg): return "A.X 4.0 API 오류: \(msg)"
        case .serviceUnavailable: return "A.X 4.0 게스트 API 종료됨"
        case .networkError(let err): return "A.X 4.0 네트워크 오류: \(err.localizedDescription)"
        }
    }
}

struct AX4Service {
    private let baseURL = "https://guest-api.sktax.chat/v1"
    private let model = "ax4"

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
            "IT/개발", "게임", "음악", "뉴스/정치", "스포츠", "교육",
            "엔터테인먼트", "과학", "기술", "금융", "요리", "여행",
            "뉴스", "_vlog", "영화", "반려동물", "취미", "기타"
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

    private func chatCompletion(
        messages: [[String: String]],
        apiKey: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AX4Error.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1024
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        log("[AX4] 요청 시작 — 바이트 크기: \(request.httpBody?.count ?? 0)")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AX4Error.invalidResponse
        }

        let responseStr = String(data: data, encoding: .utf8) ?? ""
        log("[AX4] 응답 수신 — HTTP \(httpResponse.statusCode), 길이: \(responseStr.count)")

        guard httpResponse.statusCode == 200 else {
            log("[AX4] API 오류: \(responseStr.prefix(500))")
            throw AX4Error.apiError("HTTP \(httpResponse.statusCode): \(responseStr)")
        }

        if responseStr.contains("종료") || responseStr.contains("no longer available") {
            log("[AX4] 게스트 API 서비스 종료 감지")
            throw AX4Error.serviceUnavailable
        }

        guard let decoded = try? JSONDecoder().decode(AX4ChatResponse.self, from: data),
              let content = decoded.choices?.first?.message?.content, !content.isEmpty else {
            log("[AX4] 디코딩 실패 — 실제 응답: \(responseStr.prefix(500))")
            throw AX4Error.decodingFailed
        }

        log("[AX4] 요약 성공 — 응답 길이: \(content.count)")
        return content
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
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

private struct AX4ChatResponse: Decodable {
    let choices: [Choice]?

    struct Choice: Decodable {
        let message: Message?
    }

    struct Message: Decodable {
        let content: String?
    }
}
