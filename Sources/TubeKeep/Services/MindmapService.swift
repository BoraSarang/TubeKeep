import Foundation

@MainActor
final class MindmapService {
    static let shared = MindmapService()

    private let openRouterService = OpenRouterService()

    enum MindmapError: LocalizedError {
        case noTranscript
        case apiFailed(String)
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .noTranscript: return "자막이 없습니다"
            case .apiFailed(let msg): return "마인드맵 생성 실패: \(msg)"
            case .parsingFailed: return "마인드맵 응답 파싱 실패"
            }
        }
    }

    func generate(
        videoId: String,
        transcript: String,
        title: String,
        channel: String,
        openRouterAPIKey: String
    ) async throws -> MindmapNode {
        log("[Mindmap] 생성 시작 — videoId: \(videoId)")

        let prompt = buildPrompt(title: title, channel: channel, transcript: transcript)

        let responseText: String
        do {
            responseText = try await openRouterService.chatCompletion(
                prompt: prompt,
                apiKey: openRouterAPIKey,
                systemMessage: "당신은 YouTube 영상 내용을 마인드맵으로 구조화하는 전문가입니다. 반드시 한국어로만 답변하세요."
            )
        } catch {
            log("[Mindmap] ❌ API 호출 실패: \(error.localizedDescription)")
            throw MindmapError.apiFailed(error.localizedDescription)
        }

        log("[Mindmap] 응답 수신 — 길이: \(responseText.count)")

        log("[Mindmap] 파싱 시작")
        let node = try parseResponse(responseText)
        log("[Mindmap] 파싱 완료 — 노드: \(countNodes(node))개")

        // DB 저장
        if let data = try? JSONEncoder().encode(node) {
            var aiData = DatabaseManager.shared.loadVideoAIData(videoId: videoId) ?? VideoAIData(videoId: videoId)
            aiData.mindmap = data
            DatabaseManager.shared.saveVideoAIData(aiData)
            log("[Mindmap] DB 저장 완료 — videoId: \(videoId)")
        }

        return node
    }

    private func buildPrompt(title: String, channel: String, transcript: String) -> String {
        return """
        다음 YouTube 영상의 자막을 분석하여 마인드맵( mind map )을 JSON 형식으로 생성해 주세요.

        제목: \(title)
        채널: \(channel)

        자막 내용:
        \(transcript.prefix(15000))

        규칙:
        1. 최상위 노드는 영상의 주제를 나타냅니다
        2. 2단계 노드는 주요 섹션/주제를 나타냅니다 (3~5개)
        3. 3단계 노드는 세부 내용을 나타냅니다
        4. 각 노드는 간결하게 한국어로 작성하세요 (10자 이내 권장)
        5. 깊이는 최대 3단계까지만 생성하세요
        6. 반드시 유효한 JSON만 출력하세요. 다른 설명이나 마크다운은 포함하지 마세요.

        JSON 형식:
        {
          "label": "중심 주제",
          "children": [
            {
              "label": "섹션 1",
              "children": [
                { "label": "세부 내용 1", "children": [] },
                { "label": "세부 내용 2", "children": [] }
              ]
            },
            {
              "label": "섹션 2",
              "children": [
                { "label": "세부 내용 3", "children": [] }
              ]
            }
          ]
        }
        """
    }

    private func parseResponse(_ response: String) throws -> MindmapNode {
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        log("[Mindmap] 파싱 시도 — 정제된 길이: \(cleaned.count)")
        log("[Mindmap] 정제된 응답 시작: \(cleaned.prefix(500))")

        guard let data = cleaned.data(using: .utf8) else {
            log("[Mindmap] ❌ UTF-8 인코딩 실패")
            throw MindmapError.parsingFailed
        }

        do {
            let node = try JSONDecoder().decode(MindmapNode.self, from: data)
            log("[Mindmap] JSON 디코딩 성공 — label: \(node.label)")
            return node
        } catch {
            log("[Mindmap] ❌ JSON 디코딩 실패: \(error.localizedDescription)")
            throw MindmapError.parsingFailed
        }
    }

    private func countNodes(_ node: MindmapNode) -> Int {
        return 1 + node.children.reduce(0) { $0 + countNodes($1) }
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
