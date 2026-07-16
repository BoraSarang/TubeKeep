import Foundation

actor SummarizationService {
    struct SummaryResult: Equatable {
        let overview: String
        let keyPoints: [String]
    }

    enum SummaryError: LocalizedError {
        case noSubtitle
        case transcriptionFailed(String)
        case summaryFailed(String)
        case quotaExceeded
        case apiUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .noSubtitle: return "자막을 찾을 수 없습니다"
            case let .transcriptionFailed(msg): return "음성 변환 실패: \(msg)"
            case let .summaryFailed(msg): return "요약 생성 실패: \(msg)"
            case .quotaExceeded: return "yTeaser 할당량(50회)을 초과했습니다. 내일 다시 시도해주세요."
            case let .apiUnavailable(msg): return msg
            }
        }
    }

    func summarize(videoId: String, title: String, channel: String, apiKey: String) async throws -> SummaryResult {
        let text = try await fetchTranscript(videoId: videoId)
        return try await generateSummary(text: text, title: title, channel: channel, apiKey: apiKey)
    }

    func summarizeFromLocalFile(videoPath: String, title: String, channel: String, apiKey: String) async throws -> SummaryResult {
        let text = try await extractTranscriptFromLocalFile(videoPath: videoPath)
        return try await generateSummary(text: text, title: title, channel: channel, apiKey: apiKey)
    }

    // MARK: - yTeaser API

    func summarizeWithYTeaser(videoId: String, title: String, channel: String) async throws -> SummaryResult {
        let urlString = "https://www.youtube.com/watch?v=\(videoId)"
        let apiURL = URL(string: "https://yteaser.com/api/summarize")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["url": urlString]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.apiUnavailable("yTeaser에 연결할 수 없습니다.")
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw SummaryError.quotaExceeded
            }
            let detail = Self.parseAPIError(data: data)
            throw SummaryError.summaryFailed(detail ?? "yTeaser 오류 (HTTP \(httpResponse.statusCode))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String
        else {
            throw SummaryError.summaryFailed("yTeaser 응답 파싱 실패")
        }

        let keyPoints: [String] = {
            guard let raw = json["keyPoints"] as? [String] else { return [] }
            return raw
        }()

        return SummaryResult(overview: summary, keyPoints: keyPoints)
    }

    // MARK: - Subtitle Fetching

    private func fetchTranscript(videoId: String) async throws -> String {
        let videoURL = "https://www.youtube.com/watch?v=\(videoId)"
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("tubekeep_subs_\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let outputTemplate = tmpDir.appendingPathComponent("%(id)s.%(ext)s").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            Constants.ytDlpPath,
            "--write-subs", "--write-auto-subs",
            "--sub-langs", "en,ko",
            "--skip-download",
            "--no-warnings",
            "-o", outputTemplate,
            videoURL,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let files = (try? fm.contentsOfDirectory(atPath: tmpDir.path)) ?? []

        for file in files {
            let path = tmpDir.appendingPathComponent(file)
            if file.hasSuffix(".vtt") {
                let content = try String(contentsOf: path, encoding: .utf8)
                let text = parseVTT(content)
                if !text.isEmpty { return text }
            } else if file.hasSuffix(".srt") {
                let content = try String(contentsOf: path, encoding: .utf8)
                let text = parseSRT(content)
                if !text.isEmpty { return text }
            }
        }
        throw SummaryError.noSubtitle
    }

    private func extractTranscriptFromLocalFile(videoPath: String) async throws -> String {
        let subsDir = (videoPath as NSString).deletingLastPathComponent
        let basename = ((videoPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let comps = basename.components(separatedBy: ".")
        guard let videoId = comps.last else { throw SummaryError.noSubtitle }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: subsDir)) ?? []

        for file in files {
            let fullPath = (subsDir as NSString).appendingPathComponent(file)
            guard file.contains(videoId) else { continue }
            if file.hasSuffix(".vtt") {
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                let text = parseVTT(content)
                if !text.isEmpty { return text }
            } else if file.hasSuffix(".srt") {
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                let text = parseSRT(content)
                if !text.isEmpty { return text }
            }
        }

        return try await fetchTranscript(videoId: videoId)
    }

    // MARK: - Subtitle Parsing

    private func parseVTT(_ content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        lines.removeAll { $0.hasPrefix("WEBVTT") || $0.hasPrefix("NOTE") }
        var textLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.contains("-->") { continue }
            if trimmed.rangeOfCharacter(from: .decimalDigits) != nil,
               trimmed.components(separatedBy: ":").count >= 3 { continue }
            textLines.append(trimmed)
        }
        return textLines.joined(separator: " ")
    }

    private func parseSRT(_ content: String) -> String {
        let blocks = content.components(separatedBy: "\n\n")
        var textLines: [String] = []
        for block in blocks {
            let lines = block.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if trimmed.contains("-->") { continue }
                if Int(trimmed) != nil { continue }
                textLines.append(trimmed)
            }
        }
        return textLines.joined(separator: " ")
    }

    // MARK: - LLM Summary

    private func generateSummary(text: String, title: String, channel: String, apiKey: String) async throws -> SummaryResult {
        let prompt = """
        You are a helpful assistant that summarizes YouTube videos concisely in Korean.

        Video Title: \(title)
        Channel: \(channel)

        Transcript:
        \(text.prefix(15000))

        Provide a summary in this format:
        개요: [2-3 sentence overview]

        핵심 포인트:
        • [key point 1]
        • [key point 2]
        • [key point 3]
        ...

        Keep the overview concise and the key points specific to the content.
        """

        let response = try await queryGemini(prompt: prompt, apiKey: apiKey)
        return parseSummaryResponse(response)
    }

    private func queryGemini(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

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
                    throw SummaryError.apiUnavailable("Gemini API에 연결할 수 없습니다.")
                }
                guard httpResponse.statusCode == 200 else {
                    let detail = Self.parseAPIError(data: data)
                    if httpResponse.statusCode == 429 {
                        lastDetail = detail
                        continue
                    }
                    switch httpResponse.statusCode {
                    case 400:
                        throw SummaryError.summaryFailed(detail ?? "API 키가 올바르지 않습니다. 설정에서 API 키를 확인해주세요.")
                    case 403:
                        throw SummaryError.summaryFailed(detail ?? "API 키에 권한이 없습니다. 설정에서 API 키를 확인해주세요.")
                    default:
                        throw SummaryError.summaryFailed(detail ?? "Gemini API 오류 (HTTP \(httpResponse.statusCode))")
                    }
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let firstPart = parts.first,
                      let result = firstPart["text"] as? String
                else {
                    throw SummaryError.summaryFailed("Gemini API 응답 파싱 실패")
                }
                return result
            }
        }
        if let detail = lastDetail {
            throw SummaryError.summaryFailed("요청 한도 초과: \(detail)")
        }
        throw SummaryError.apiUnavailable("Gemini API 요청 실패")
    }

    private static func parseAPIError(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return nil }
        return message
    }

    private func parseSummaryResponse(_ response: String) -> SummaryResult {
        var overview = ""
        var keyPoints: [String] = []

        let lines = response.components(separatedBy: .newlines)
        var foundPoints = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("개요:") || trimmed.hasPrefix("개요 :") {
                let idx = trimmed.hasPrefix("개요:") ? 3 : 4
                overview = String(trimmed.dropFirst(idx)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("핵심 포인트:") || trimmed.hasPrefix("핵심 포인트 :") {
                foundPoints = true
            } else if foundPoints, trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                let point = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !point.isEmpty { keyPoints.append(point) }
            } else if !foundPoints, !overview.isEmpty, !trimmed.isEmpty, !trimmed.hasPrefix("핵심") {
                if trimmed.range(of: "^[\\s\\*\\-]*$", options: .regularExpression) == nil {
                    overview += " " + trimmed
                }
            }
        }

        if overview.isEmpty {
            overview = String(response.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return SummaryResult(overview: overview, keyPoints: keyPoints)
    }
}
