import Foundation

enum NVIDIAError: LocalizedError {
    case invalidAPIKey
    case noModelSelected
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "NVIDIA API 키가 없습니다. 설정 → 공급자에서 입력해 주세요."
        case .noModelSelected: return "사용 중으로 켠 NVIDIA 모델이 없습니다. 모델 탭에서 토글을 켜 주세요."
        case let .apiError(msg): return "NVIDIA NIM 오류: \(msg)"
        }
    }
}

/// NVIDIA NIM 클라이언트 — OpenAI 호환 (integrate.api.nvidia.com/v1)
struct NVIDIAService {
    static let baseURL = "https://integrate.api.nvidia.com/v1"
    static let defaultModel = "meta/llama-3.1-8b-instruct"

    /// 자주 쓰는 모델 — 모델 목록 최상단 고정
    static let preferredModelIDs = [
        "openai/gpt-oss-20b",
        "nvidia/llama-3.3-nemotron-super-49b-v1.5",
    ]

    /// 사용자가 토글로 켠 모델들 (순서대로 시도). 비어있으면 기본값.
    static var enabledModels: [String] {
        let list = CloudModelPrefs.enabled(.nvidia)
        return list.isEmpty ? [defaultModel] : list
    }

    /// 모델 목록 조회 (API 키 필요)
    static func listModels(apiKey: String) async throws -> [CloudModelInfo] {
        guard !apiKey.isEmpty else { throw NVIDIAError.invalidAPIKey }
        guard let url = URL(string: "\(baseURL)/models") else {
            throw NVIDIAError.apiError("URL 생성 실패")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        log("[Settings] NVIDIA 모델 목록 조회 시작")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("[Settings] NVIDIA 모델 조회 실패 — HTTP \(status)")
            throw NVIDIAError.apiError("HTTP \(status)")
        }

        struct ModelsResponse: Decodable {
            struct Entry: Decodable { let id: String; let owned_by: String? }
            let data: [Entry]?
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let models = (decoded.data ?? [])
            .map { entry in
                CloudModelInfo(
                    id: entry.id,
                    displayName: "",
                    subtitle: entry.owned_by ?? "",
                    contextLength: nil,
                    isFree: false
                )
            }
            .sorted { a, b in
                let ai = preferredModelIDs.firstIndex(of: a.id) ?? Int.max
                let bi = preferredModelIDs.firstIndex(of: b.id) ?? Int.max
                if ai != bi { return ai < bi }
                return a.id < b.id
            }
        log("[Settings] ✅ NVIDIA 모델 목록 성공 — \(models.count)개")
        return models
    }

    /// 채인용 편의 진입 — 토글로 켠 모델들을 순서대로 시도, 첫 성공 반환
    static func tryChat(
        prompt: String,
        apiKey: String,
        systemMessage: String,
        timeout: TimeInterval = 60
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw NVIDIAError.invalidAPIKey }

        let models = enabledModels
        var lastError: Error = NVIDIAError.noModelSelected
        for model in models {
            do {
                return try await chat(model: model, apiKey: apiKey, prompt: prompt, systemMessage: systemMessage, timeout: timeout)
            } catch {
                lastError = error
                log("[AI Route] NVIDIA(\(model)) 실패 → 다음 사용 모델 시도 (\(error.localizedDescription))")
            }
        }
        throw lastError
    }

    private static func chat(
        model: String,
        apiKey: String,
        prompt: String,
        systemMessage: String,
        timeout: TimeInterval = 60
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NVIDIAError.apiError("URL 생성 실패")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": prompt],
            ],
            "temperature": 0.3,
            "max_tokens": 4096,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        log("[AI Route] NVIDIA(\(model)) 요청 시작")
        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                log("[AI Route] NVIDIA HTTP \(status)")
                throw NVIDIAError.apiError("HTTP \(status)")
            }
            data = responseData
        } catch let error as NVIDIAError {
            throw error
        } catch {
            log("[AI Route] NVIDIA 실패 — \(error.localizedDescription)")
            throw NVIDIAError.apiError(error.localizedDescription)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content, !content.isEmpty else {
            log("[AI Route] NVIDIA 응답 디코딩 실패")
            throw NVIDIAError.apiError("응답 해석 실패")
        }

        log("[AI Route] ✅ NVIDIA(\(model)) 성공 — 응답 길이: \(content.count)")
        return content
    }

    private static func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
