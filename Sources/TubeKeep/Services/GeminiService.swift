import Foundation

enum GeminiError: LocalizedError {
    case quotaExceeded(String?)
    case apiError(Int, String?)
    case invalidResponse
    case connectionFailed
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .quotaExceeded(let detail): return detail.map { "요청 한도 초과: \($0)" } ?? "요청 한도 초과"
        case .apiError(let code, let detail): return detail ?? "Gemini API 오류 (HTTP \(code))"
        case .invalidResponse: return "Gemini API 응답이 없습니다"
        case .connectionFailed: return "Gemini API에 연결할 수 없습니다."
        case .parsingFailed: return "Gemini API 응답 파악 실패"
        }
    }
}

struct GeminiService {
    private let timeoutInterval: TimeInterval = 60

    func query(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)") else {
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
}
