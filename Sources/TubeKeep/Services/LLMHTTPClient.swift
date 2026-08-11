import Foundation

enum LLMHTTPError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpStatus(Int, Data?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 URL입니다."
        case let .networkError(err): return "네트워크 오류: \(err.localizedDescription)"
        case let .httpStatus(code, _): return "HTTP 오류 (\(code))"
        case .decodingFailed: return "응답 해석 실패"
        }
    }
}

/// LLM HTTP 요청 공통 클라이언트 — POST JSON + 공통 지수 백오프(429 재시도)를 한 곳에서 처리한다.
struct LLMHTTPClient {
    /// POST JSON 요청 + 429 시 지수 백오프 재시도.
    /// - Parameters:
    ///   - url: 요청 URL
    ///   - body: JSON 인코딩할 바디
    ///   - apiKey: Bearer 인증 키 (nil이면 Authorization 헤더 생략)
    ///   - headers: 추가 헤더
    ///   - timeout: 요청 타임아웃
    ///   - maxAttempts: 최대 시도 횟수 (1 = 재시도 없음). 429일 때만 재시도한다.
    ///   - baseDelaySeconds: 지수 백오프 기본 지연 (n번째 재시도 = n * baseDelay)
    ///   - statusHandler: 각 응답 상태 로깅 훅 (모든 응답에 호출됨)
    static func postJSON(
        url: URL,
        body: [String: Any],
        apiKey: String? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval = 45,
        maxAttempts: Int = 1,
        baseDelaySeconds: Double = 2.0,
        statusHandler: ((Int, Data?) -> Void)? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                let delay = Double(attempt) * baseDelaySeconds
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw LLMHTTPError.networkError(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMHTTPError.decodingFailed
            }

            statusHandler?(httpResponse.statusCode, data)

            if httpResponse.statusCode == 200 {
                return data
            }
            if httpResponse.statusCode == 429, attempt < maxAttempts - 1 {
                continue
            }
            throw LLMHTTPError.httpStatus(httpResponse.statusCode, data)
        }

        throw LLMHTTPError.httpStatus(0, nil)
    }
}
