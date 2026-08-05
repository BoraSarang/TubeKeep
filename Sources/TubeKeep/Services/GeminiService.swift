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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastDetail: String?
        for attempt in 0..<4 {
            if attempt > 0 {
                let delay = Double(min(attempt, 4)) * 2.0
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiError.connectionFailed
                }
                guard httpResponse.statusCode == 200 else {
                    let detail = Self.parseAPIError(data: data)
                    if httpResponse.statusCode == 429 {
                        lastDetail = detail
                        continue
                    }
                    throw GeminiError.apiError(httpResponse.statusCode, detail)
                }
                return try Self.parseResponse(data: data)
            }
        }
        throw GeminiError.quotaExceeded(lastDetail)
    }

    private static func parseAPIError(data: Data) -> String? {
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
