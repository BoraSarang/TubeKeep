import Foundation

@MainActor
final class QAService {
    static let shared = QAService()

    private let openRouterService = OpenRouterService()
    private let databaseManager = DatabaseManager.shared

    enum QAError: LocalizedError {
        case noTranscript
        case apiFailed(String)
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .noTranscript: return "자막이 없습니다"
            case .apiFailed(let msg): return "Q&A 실패: \(msg)"
            case .parsingFailed: return "응답 파싱 실패"
            }
        }
    }

    // MARK: - Q&A 질문하기

    func ask(
        videoId: String,
        question: String,
        transcript: String,
        title: String,
        openRouterAPIKey: String
    ) async throws -> QAResponse {
        log("[Q&A] 질문 시작 — videoId: \(videoId), 질문: \(question)")

        let prompt = buildPrompt(question: question, transcript: transcript, title: title)

        let responseText: String
        do {
            responseText = try await openRouterService.chatCompletion(
                prompt: prompt,
                apiKey: openRouterAPIKey,
                systemMessage: "절대로 영어를 사용하지 마세요. 반드시 한국어로만 답변하세요. 자막 원문을 그대로 복사하지 마세요. 자신의 말로 요약해서 답변하세요."
            )
        } catch {
            throw QAError.apiFailed(error.localizedDescription)
        }

        log("[Q&A] 응답 수신 — 길이: \(responseText.count)")

        let parsed = parseResponse(responseText, question: question)
        log("[Q&A] 파싱 완료 — 타임스탬프: \(parsed.timestamps.count)개")

        // 히스토리 저장
        let historyId = databaseManager.saveQAHistory(
            videoId: videoId,
            question: question,
            answer: parsed.answer,
            timestamps: parsed.timestamps
        )
        log("[Q&A] 히스토리 저장 — id: \(historyId)")

        return parsed
    }

    // MARK: - 히스토리 로드

    func loadHistory(videoId: String) -> [QAHistoryItem] {
        return databaseManager.loadQAHistory(videoId: videoId)
    }

    // MARK: - 히스토리 삭제

    func deleteHistory(id: Int64) {
        databaseManager.deleteQAHistory(id: id)
    }

    func deleteAllHistory(videoId: String) {
        databaseManager.deleteAllQAHistory(videoId: videoId)
    }

    // MARK: - 프롬프트 빌드

    private func buildPrompt(question: String, transcript: String, title: String) -> String {
        return """
        다음 YouTube 영상의 자막을 바탕으로 질문에 답변해 주세요.

        **중요 규칙:**
        - 반드시 한국어로만 답변하세요. 영어 답변은 절대 금지입니다.
        - 자막 원문을 그대로 복사하지 마세요. 반드시 자신의 말로 요약하여 답변하세요.
        - 사고 과정(Let me think, We need to 등)을 출력하지 마세요.

        영상 제목: \(title)

        자막 내용:
        \(transcript.prefix(15000))

        질문: \(question)

        답변 규칙:
        1. 자막 내용에 기반하여 정확하게 답변하세요
        2. 답변 중 관련된 부분의 타임스탬프를 [MM:SS] 형식으로 포함하세요
        3. 타임스탬프는 최대 3개까지 포함하세요
        4. 간결하고 명확하게 한국어로 답변하세요

        답변 형식:
        (질문에 대한 답변 내용, 타임스탬프 포함)

        타임스탬프:
        - [MM:SS] 관련 설명
        - [MM:SS] 관련 설명
        """
    }

    // MARK: - 응답 파싱

    private func parseResponse(_ response: String, question: String) -> QAResponse {
        var timestamps: [QATimestamp] = []
        var answer = response

        // 타임스탬프 부분 분리
        if let tsStart = response.range(of: "타임스탬프:") {
            let tsSection = String(response[tsStart.upperBound...])
            answer = String(response[response.startIndex..<tsStart.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

            // [MM:SS] 패턴 추출
            let pattern = #"\[(\d{1,2}):(\d{2})\]\s*(.*?)(?=\n|$)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(tsSection.startIndex..<tsSection.endIndex, in: tsSection)
                for match in regex.matches(in: tsSection, range: nsRange) {
                    guard let minRange = Range(match.range(at: 1), in: tsSection),
                          let secRange = Range(match.range(at: 2), in: tsSection),
                          let descRange = Range(match.range(at: 3), in: tsSection) else { continue }

                    let minutes = Int(tsSection[minRange]) ?? 0
                    let seconds = Int(tsSection[secRange]) ?? 0
                    let timeStr = "\(tsSection[minRange]):\(tsSection[secRange])"
                    let startTime = Double(minutes * 60 + seconds)
                    let description = String(tsSection[descRange]).trimmingCharacters(in: .whitespaces)

                    timestamps.append(QATimestamp(
                        time: timeStr,
                        startTime: startTime,
                        description: description
                    ))
                }
            }
        }

        // 답변에서 타임스탬프도 추출 (답변 본문에 있는 경우)
        let inlinePattern = #"\[(\d{1,2}):(\d{2})\]"#
        if let regex = try? NSRegularExpression(pattern: inlinePattern) {
            let nsRange = NSRange(response.startIndex..<response.endIndex, in: response)
            for match in regex.matches(in: response, range: nsRange) {
                guard let minRange = Range(match.range(at: 1), in: response),
                      let secRange = Range(match.range(at: 2), in: response) else { continue }

                let minutes = Int(response[minRange]) ?? 0
                let seconds = Int(response[secRange]) ?? 0
                let timeStr = "\(response[minRange]):\(response[secRange])"
                let startTime = Double(minutes * 60 + seconds)

                // 이미 같은 타임스탬프가 없으면 추가
                if !timestamps.contains(where: { $0.startTime == startTime }) {
                    timestamps.append(QATimestamp(
                        time: timeStr,
                        startTime: startTime,
                        description: ""
                    ))
                }
            }
        }

        return QAResponse(
            question: question,
            answer: answer,
            timestamps: timestamps.sorted { $0.startTime < $1.startTime }
        )
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
