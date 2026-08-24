import Foundation

enum GeminiError: LocalizedError {
    case quotaExceeded(String?)
    case apiError(Int, String?)
    case invalidResponse
    case connectionFailed
    case parsingFailed
    case invalidAPIKey

    var errorDescription: String? {
        switch self {
        case .quotaExceeded(let detail): return detail.map { "요청 한도 초과: \($0)" } ?? "요청 한도 초과"
        case .apiError(let code, let detail): return detail ?? "Gemini API 오류 (HTTP \(code))"
        case .invalidResponse: return "Gemini API 응답이 없습니다"
        case .connectionFailed: return "Gemini API에 연결할 수 없습니다."
        case .parsingFailed: return "Gemini API 응답 파악 실패"
        case .invalidAPIKey: return "Gemini API 키가 없습니다. 설정 → 공급자에서 입력해 주세요."
        }
    }
}

struct GeminiService {
    private let timeoutInterval: TimeInterval = 60
    private static let defaultModel = "gemini-2.0-flash"

    /// 설치 가능한 Gemini 모델 목록 — AIModelTalk refreshGemini와 동일 기준
    /// (pageSize 1000 · 채팅 불가 계열 제외 · generateContent 지원만)
    static func listModels(apiKey: String) async throws -> [CloudModelInfo] {
        guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)&pageSize=1000") else {
            throw GeminiError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        log("[Settings] Gemini 모델 목록 조회 시작")
        let (data, response) = try await URLSession.shared.data(for: request)

        // 에러 응답 명시 처리 — 실패가 조용히 빈 목록이 되지 않도록 한다
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = parseAPIError(data: data) ?? "HTTP \(http.statusCode)"
            log("[Settings] Gemini 모델 조회 실패 — HTTP \(http.statusCode): \(message)")
            throw GeminiError.apiError(http.statusCode, message)
        }

        struct ModelsResponse: Decodable {
            struct Entry: Decodable {
                let name: String
                let displayName: String?
                let supportedGenerationMethods: [String]?
                let inputTokenLimit: Int?
            }
            let models: [Entry]?
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let excludedKeywords = ["embedding", "aqa", "imagen", "veo", "tts"]
        let models = (decoded.models ?? [])
            .filter { entry in
                guard entry.supportedGenerationMethods?.contains("generateContent") == true else { return false }
                return !excludedKeywords.contains(where: { entry.name.lowercased().contains($0) })
            }
            .map { entry in
                CloudModelInfo(
                    id: entry.name.replacingOccurrences(of: "models/", with: ""),
                    displayName: entry.displayName ?? "",
                    contextLength: entry.inputTokenLimit,
                    isFree: false
                )
            }
            .sorted { $0.id < $1.id }
        log("[Settings] ✅ Gemini 모델 목록 성공 — \(models.count)개")
        return models
    }

    /// 사용자가 모델 탭에서 토글로 켠 모델들 (순서대로 시도). 비어있으면 기본값.
    static var enabledModels: [String] {
        let list = CloudModelPrefs.enabled(.gemini)
        return list.isEmpty ? [defaultModel] : list
    }

    func query(prompt: String, apiKey: String) async throws -> String {
        let models = Self.enabledModels
        var lastError: Error = GeminiError.invalidResponse
        for model in models {
            do {
                let result = try await queryOnce(prompt: prompt, apiKey: apiKey, model: model)
                if models.count > 1 {
Self.log("[AI Route] ✅ Gemini(\(model)) 성공 — 응답 길이: \(result.count)")
                }
                return result
            } catch {
                lastError = error
Self.log("[AI Route] Gemini(\(model)) 실패 → 다음 사용 모델 시도 (\(error.localizedDescription))")
            }
        }
        throw lastError
    }

    private func queryOnce(prompt: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]

        let data: Data
        do {
            data = try await LLMHTTPClient.postJSON(
                url: url,
                body: body,
                timeout: timeoutInterval,
                maxAttempts: 4,
                baseDelaySeconds: 2.0
            )
        } catch let error as LLMHTTPError {
            switch error {
            case .networkError, .decodingFailed:
                throw GeminiError.connectionFailed
            case let .httpStatus(code, data):
                let detail = Self.parseAPIError(data: data)
                if code == 429 {
                    throw GeminiError.quotaExceeded(detail)
                }
                throw GeminiError.apiError(code, detail)
            case .invalidURL:
                throw GeminiError.invalidResponse
            }
        }
        return try Self.parseResponse(data: data)
    }

    private static func parseAPIError(data: Data?) -> String? {
        guard let data else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return nil }
        return message
    }

    private static func parseResponse(data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let result = firstPart["text"] as? String
        else {
            throw GeminiError.parsingFailed
        }
        return result
    }

    private static func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
