import Foundation

enum OllamaError: LocalizedError {
    case serverNotRunning
    case noModelSelected
    case modelNotFound(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning: return "Ollama 서버에 연결할 수 없습니다"
        case .noModelSelected: return "사용할 Ollama 모델이 선택되지 않았습니다"
        case .modelNotFound(let m): return "Ollama 모델(\(m))을 찾을 수 없습니다"
        case .apiError(let msg): return "Ollama 오류: \(msg)"
        }
    }
}

/// 로컬 Ollama 클라이언트 — 네이티브 /api/chat 사용 (options.num_ctx 적용 보장).
/// 모든 AI 체인의 최우선 프로바이더. 실패 시 호출측에서 클라우드 체인으로 폴백한다.
struct OllamaService {
    static let defaultBaseURL = "http://localhost:11434"

    /// 요약 15,000자 입력을 소화하기 위한 컨텍스트 (Ollama 기본 2048은 부족)
    private let numCtx = 8192
    /// 14b 로컬 추론 장문 출력 대비 넉넉한 타임아웃
    private let requestTimeout: TimeInterval = 300

    // MARK: - 설정 값

    static var baseURL: String {
        UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? defaultBaseURL
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "ollamaEnabled") as? Bool ?? true
    }

    static var selectedModel: String {
        UserDefaults.standard.string(forKey: "ollamaModel") ?? ""
    }

    /// 토글로 켠 모델들 (배열 순서대로 시도). 비어있으면 기존 단일 선택값.
    static var enabledModels: [String] {
        let list = CloudModelPrefs.enabled(.ollama)
        return list.isEmpty ? (selectedModel.isEmpty ? [] : [selectedModel]) : list
    }

    // MARK: - 감지 (60초 캐시 — 반복 감지로 UX 지연 방지)

    private static let cacheLock = NSLock()
    private nonisolated(unsafe) static var cachedRunning: Bool?
    private nonisolated(unsafe) static var cacheTimestamp: Date = .distantPast

    static func invalidateServerCache() {
        cacheLock.lock()
        cachedRunning = nil
        cacheTimestamp = .distantPast
        cacheLock.unlock()
    }

    /// 서버 실행 여부 (2초 타임아웃, 60초 캐시)
    static func isServerRunning() async -> Bool {
        cacheLock.lock()
        if let cached = cachedRunning, Date().timeIntervalSince(cacheTimestamp) < 60 {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        let running: Bool
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            running = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            running = false
        }

        cacheLock.lock()
        cachedRunning = running
        cacheTimestamp = Date()
        cacheLock.unlock()

        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append("[AI Route] Ollama 서버 감지: \(running ? "실행 중" : "꺼짐")")
        }
        #endif
        return running
    }

    /// 설치된 모델 이름 목록 (서버 꺼지면 빈 배열)
    static func listModels() async -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct TagsResponse: Decodable { let models: [ModelEntry] }
            struct ModelEntry: Decodable { let name: String }
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            return decoded.models.map(\.name).sorted()
        } catch {
            return []
        }
    }

    /// 모델 설치 (ollama pull) — NDJSON 스트림에서 진행률 파싱해 콜백으로 전달
    static func pullModel(
        _ name: String,
        onProgress: @escaping @Sendable (_ fraction: Double, _ statusText: String) -> Void
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/pull") else {
            throw OllamaError.apiError("URL 생성 실패")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3600 // 대형 모델 다운로드 대비 넉넉한 타임아웃
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OllamaError.apiError("HTTP \(status)")
        }

        var lastFraction = -1.0
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else { continue }

            if let error = json["error"] as? String {
                throw OllamaError.apiError(error)
            }

            let total = (json["total"] as? Int64) ?? 0
            let completed = (json["completed"] as? Int64) ?? 0
            if total > 0 && completed > 0 {
                let fraction = Double(completed) / Double(total)
                if abs(fraction - lastFraction) >= 0.01 || fraction >= 1.0 {
                    lastFraction = fraction
                    onProgress(fraction, status)
                }
            } else {
                onProgress(lastFraction < 0 ? 0 : lastFraction, status)
            }
        }
    }

    /// 모델 삭제
    static func deleteModel(_ name: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/delete") else {
            throw OllamaError.apiError("URL 생성 실패")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OllamaError.apiError("HTTP \(status)")
        }
    }

    /// AI 체인용 선행 시도 — 활성 && 서버 응답 && 사용 모델 있을 때만 의미 있음.
    /// 토글로 켠 모델들을 순서대로 시도(설치된 것만), 첫 성공 반환. 실패 시 throw → 폴백.
    static func tryLocalChat(
        prompt: String,
        systemMessage: String,
        timeout: TimeInterval = 300
    ) async throws -> String {
        guard isEnabled else { throw OllamaError.serverNotRunning }
        guard await isServerRunning() else { throw OllamaError.serverNotRunning }

        let models = await listModels()
        let candidates = enabledModels.filter { models.contains($0) }
        guard !candidates.isEmpty else {
            throw enabledModels.isEmpty ? OllamaError.noModelSelected : OllamaError.modelNotFound(enabledModels.joined(separator: ", "))
        }

        var lastError: Error = OllamaError.noModelSelected
        for model in candidates {
            do {
                return try await OllamaService(requestTimeout: timeout).chat(
                    model: model,
                    systemMessage: systemMessage,
                    prompt: prompt
                )
            } catch {
                lastError = error
                #if DEBUG
                Task { @MainActor in
                    DebugLogManager.shared?.append("[AI Route] Ollama(\(model)) 실패 → 다음 사용 모델 시도 (\(error.localizedDescription))")
                }
                #endif
            }
        }
        throw lastError
    }

    // MARK: - Chat Completion

    private let effectiveTimeout: TimeInterval

    init(requestTimeout: TimeInterval = 300) {
        self.effectiveTimeout = requestTimeout
    }

    func chat(model: String, systemMessage: String, prompt: String) async throws -> String {
        guard let url = URL(string: "\(Self.baseURL)/api/chat") else {
            throw OllamaError.apiError("URL 생성 실패")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": prompt],
            ],
            "stream": false,
            "options": [
                "num_ctx": numCtx,
                "temperature": 0.3,
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = effectiveTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        log("[AI Route] Ollama(\(model)) 요청 시작 — num_ctx \(numCtx)")
        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                log("[AI Route] Ollama HTTP \(status)")
                throw OllamaError.apiError("HTTP \(status)")
            }
            data = responseData
        } catch let error as OllamaError {
            throw error
        } catch {
            log("[AI Route] Ollama 실패 — \(error.localizedDescription)")
            throw OllamaError.apiError(error.localizedDescription)
        }

        struct ChatResponse: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              !decoded.message.content.isEmpty else {
            log("[AI Route] Ollama 응답 디코딩 실패")
            throw OllamaError.apiError("응답 해석 실패")
        }

        log("[AI Route] ✅ Ollama(\(model)) 성공 — 응답 길이: \(decoded.message.content.count)")
        return decoded.message.content
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
