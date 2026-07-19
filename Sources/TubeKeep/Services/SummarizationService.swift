import Foundation

struct ChapterInfo: Codable, Equatable, Identifiable {
    var id: String { "\(startTime)" }
    let title: String
    let startTime: Double
    let endTime: Double

    var startTimeFormatted: String {
        let mins = Int(startTime) / 60
        let secs = Int(startTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var endTimeFormatted: String {
        let mins = Int(endTime) / 60
        let secs = Int(endTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

actor SummarizationService {
    struct SummaryResult: Equatable {
        let overview: String
        let keyPoints: [String]
        let chapters: [ChapterInfo]
        let provider: String
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
            case .quotaExceeded: return "yTeaser 할당량(50회)을 초과했습니다. 내일 다시 시도해 주세요."
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

    func summarizeVideo(videoId: String, title: String, channel: String, openRouterAPIKey: String, ax4APIKey: String, geminiAPIKey: String, localFilePath: String? = nil) async throws -> SummaryResult {
        log("[AI Fallback] 요약 시작 — videoId: \(videoId), title: \(title)")

        // DB 캐시 확인 — 기존 요약이 있으면 바로 반환
        if let cached = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
           let summary = cached.summary, !summary.isEmpty {
            log("[AI Fallback] ✅ DB 캐시 히트 — videoId: \(videoId)")
            let chapters: [ChapterInfo] = {
                guard let data = cached.chapters else { return [] }
                return (try? JSONDecoder().decode([ChapterInfo].self, from: data)) ?? []
            }()
            return SummaryResult(overview: summary, keyPoints: [], chapters: chapters, provider: "cached")
        }

        log("[AI Fallback] 사용 가능한 서비스 — OpenRouter: \(openRouterAPIKey.isEmpty ? "없음" : "있음"), A.X: \(ax4APIKey.isEmpty ? "없음" : "있음"), Gemini: \(geminiAPIKey.isEmpty ? "없음" : "있음")")
        
        // 1순위: OpenRouter (무료)
        if !openRouterAPIKey.isEmpty {
            log("[AI Fallback] 1순위: OpenRouter 시도 — videoId: \(videoId)")
            do {
                let text: String
                if let path = localFilePath, FileManager.default.fileExists(atPath: path) {
                    log("[AI Fallback] 로컬 파일에서 자막 추출 시도 — path: \(path)")
                    text = try await extractTranscriptFromLocalFile(videoPath: path)
                } else {
                    log("[AI Fallback] YouTube에서 자막 다운로드 시도 — videoId: \(videoId)")
                    text = try await fetchTranscript(videoId: videoId)
                }
                log("[AI Fallback] 자막 추출 완료 — 길이: \(text.count)자")
                let service = OpenRouterService()
                let result = try await service.generateSummary(transcript: text, title: title, channel: channel, apiKey: openRouterAPIKey)
                log("[AI Fallback] ✅ OpenRouter 성공 — videoId: \(videoId)")
                return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "OpenRouter")
            } catch {
                log("[AI Fallback] ❌ OpenRouter 실패(\(error.localizedDescription)) → yTeaser 시도 — videoId: \(videoId)")
            }
        } else {
            log("[AI Fallback] OpenRouter 키 없음 → yTeaser 시도 — videoId: \(videoId)")
        }

        // 2순위: yTeaser (무료)
        log("[AI Fallback] 2순위: yTeaser 시도 — videoId: \(videoId)")
        do {
            let result = try await summarizeWithYTeaser(videoId: videoId, title: title, channel: channel)
            log("[AI Fallback] ✅ yTeaser 성공 — videoId: \(videoId)")
            return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "yTeaser")
        } catch SummaryError.quotaExceeded {
            log("[AI Fallback] ⚠️ yTeaser 할당량 초과 → A.X 4.0 시도 — videoId: \(videoId)")
        } catch {
            log("[AI Fallback] ❌ yTeaser 실패(\(error.localizedDescription)) → A.X 4.0 시도 — videoId: \(videoId)")
        }

        // 3순위: A.X 4.0
        if !ax4APIKey.isEmpty {
            log("[AI Fallback] 3순위: A.X 4.0 시도 — videoId: \(videoId)")
            do {
                let result = try await summarizeWithAX4(videoId: videoId, title: title, channel: channel, apiKey: ax4APIKey, localFilePath: localFilePath)
                log("[AI Fallback] ✅ A.X 4.0 성공 — videoId: \(videoId)")
                return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "A.X 4.0")
            } catch AX4Error.serviceUnavailable {
                log("[AI Fallback] ⚠️ A.X 4.0 게스트 API 종료 → Gemini 시도 — videoId: \(videoId)")
            } catch {
                log("[AI Fallback] ❌ A.X 4.0 실패(\(error.localizedDescription)) → Gemini 시도 — videoId: \(videoId)")
            }
        } else {
            log("[AI Fallback] A.X 4.0 키 없음 → Gemini 시도 — videoId: \(videoId)")
        }

        // 4순위: Gemini (유료)
        guard !geminiAPIKey.isEmpty else {
            log("[AI Fallback] ❌ Gemini 키 없음 → 요약 실패 — videoId: \(videoId)")
            throw SummaryError.apiUnavailable("모든 AI 요약 서비스를 사용할 수 없습니다. 설정에서 API 키를 확인해 주세요.")
        }
        log("[AI Fallback] 4순위: Gemini 시도 — videoId: \(videoId)")
        if let path = localFilePath, FileManager.default.fileExists(atPath: path) {
            let result = try await summarizeFromLocalFile(videoPath: path, title: title, channel: channel, apiKey: geminiAPIKey)
            log("[AI Fallback] ✅ Gemini 성공 (로컬 파일) — videoId: \(videoId)")
            return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "Gemini")
        }
        let result = try await summarize(videoId: videoId, title: title, channel: channel, apiKey: geminiAPIKey)
        log("[AI Fallback] ✅ Gemini 성공 — videoId: \(videoId)")
        return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "Gemini")
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }

    private func saveTranscriptToDB(videoId: String, transcript: String, language: String) {
        log("[Subtitle] DB 저장 시작 — videoId: \(videoId), 언어: \(language), 길이: \(transcript.count)자")
        var data = DatabaseManager.shared.loadVideoAIData(videoId: videoId) ?? VideoAIData(videoId: videoId)
        data.transcript = transcript
        data.transcriptLanguage = language
        DatabaseManager.shared.saveVideoAIData(data)
        log("[Subtitle] ✅ 자막 DB 저장 완료 — videoId: \(videoId)")
    }

    // MARK: - A.X 4.0 API

    func summarizeWithAX4(videoId: String, title: String, channel: String, apiKey: String, localFilePath: String? = nil) async throws -> SummaryResult {
        let text: String
        if let path = localFilePath, FileManager.default.fileExists(atPath: path) {
            text = try await extractTranscriptFromLocalFile(videoPath: path)
        } else {
            text = try await fetchTranscript(videoId: videoId)
        }
        let ax4 = AX4Service()
        let result = try await ax4.generateSummary(transcript: text, title: title, channel: channel, apiKey: apiKey)
        return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "A.X 4.0")
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

        return SummaryResult(overview: summary, keyPoints: keyPoints, chapters: [], provider: "yTeaser")
    }

    // MARK: - Subtitle Fetching

    private func fetchTranscript(videoId: String) async throws -> String {
        log("[Subtitle] 자막 가져오기 시작 — videoId: \(videoId)")
        
        // DB에서 캐시된 자막 확인
        log("[Subtitle] DB에서 캐시 확인 중 — videoId: \(videoId)")
        if let cached = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
           let transcript = cached.transcript, !transcript.isEmpty {
            log("[Subtitle] ✅ DB에서 캐시된 자막 로드 성공 — videoId: \(videoId), 길이: \(transcript.count)자")
            return transcript
        }
        log("[Subtitle] ❌ DB에 캐시된 자막 없음 — videoId: \(videoId)")

        let videoURL = "https://www.youtube.com/watch?v=\(videoId)"
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("tubekeep_subs_\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        log("[Subtitle] YouTube 자막 다운로드 시작 — videoId: \(videoId)")
        log("[Subtitle] 임시 디렉토리: \(tmpDir.path)")
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
        log("[Subtitle] yt-dlp 명령어: \(process.arguments?.joined(separator: " ") ?? "")")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        
        let exitCode = process.terminationStatus
        log("[Subtitle] yt-dlp 종료 코드: \(exitCode)")

        let files = (try? fm.contentsOfDirectory(atPath: tmpDir.path)) ?? []
        log("[Subtitle] 다운로드된 파일 수: \(files.count)")
        if files.isEmpty {
            log("[Subtitle] ⚠️ 자막 파일 없음 — videoId: \(videoId)")
        } else {
            for file in files {
                log("[Subtitle] 발견된 파일: \(file)")
            }
        }

        for file in files {
            let path = tmpDir.appendingPathComponent(file)
            if file.hasSuffix(".vtt") {
                log("[Subtitle] VTT 파일 파싱 시작: \(file)")
                let content = try String(contentsOf: path, encoding: .utf8)
                let text = Self.parseVTT(content)
                log("[Subtitle] VTT 파싱 완료 — 추출된 텍스트 길이: \(text.count)자")
                if !text.isEmpty {
                    log("[Subtitle] ✅ 자막 추출 성공 (VTT) — videoId: \(videoId), 언어: en")
                    saveTranscriptToDB(videoId: videoId, transcript: text, language: "en")
                    return text
                }
                log("[Subtitle] ⚠️ VTT에서 유효한 텍스트 없음")
            } else if file.hasSuffix(".srt") {
                log("[Subtitle] SRT 파일 파싱 시작: \(file)")
                let content = try String(contentsOf: path, encoding: .utf8)
                let text = Self.parseSRT(content)
                log("[Subtitle] SRT 파싱 완료 — 추출된 텍스트 길이: \(text.count)자")
                if !text.isEmpty {
                    log("[Subtitle] ✅ 자막 추출 성공 (SRT) — videoId: \(videoId), 언어: en")
                    saveTranscriptToDB(videoId: videoId, transcript: text, language: "en")
                    return text
                }
                log("[Subtitle] ⚠️ SRT에서 유효한 텍스트 없음")
            }
        }
        log("[Subtitle] ❌ 사용 가능한 자막 파일 없음 — videoId: \(videoId)")
        throw SummaryError.noSubtitle
    }

    private func extractTranscriptFromLocalFile(videoPath: String) async throws -> String {
        log("[Subtitle] 로컬 파일에서 자막 추출 시작 — 경로: \(videoPath)")
        let subsDir = (videoPath as NSString).deletingLastPathComponent
        let basename = ((videoPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let comps = basename.components(separatedBy: ".")
        guard let videoId = comps.last else {
            log("[Subtitle] ❌ videoId 추출 실패 — basename: \(basename)")
            throw SummaryError.noSubtitle
        }
        log("[Subtitle] videoId: \(videoId), 자막 검색 디렉토리: \(subsDir)")

        let files = (try? FileManager.default.contentsOfDirectory(atPath: subsDir)) ?? []
        log("[Subtitle] 디렉토리 내 파일 수: \(files.count)")
        
        var foundFiles: [String] = []
        for file in files {
            if file.contains(videoId) {
                foundFiles.append(file)
            }
        }
        log("[Subtitle] videoId와 일치하는 파일: \(foundFiles.joined(separator: ", "))")

        for file in files {
            let fullPath = (subsDir as NSString).appendingPathComponent(file)
            guard file.contains(videoId) else { continue }
            if file.hasSuffix(".vtt") {
                log("[Subtitle] 로컬 VTT 파일 발견: \(file)")
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                let text = Self.parseVTT(content)
                log("[Subtitle] VTT 파싱 완료 — 추출된 텍스트 길이: \(text.count)자")
                if !text.isEmpty {
                    log("[Subtitle] ✅ 로컬 자막 추출 성공 (VTT) — 파일: \(file)")
                    return text
                }
                log("[Subtitle] ⚠️ 로컬 VTT에서 유효한 텍스트 없음")
            } else if file.hasSuffix(".srt") {
                log("[Subtitle] 로컬 SRT 파일 발견: \(file)")
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                let text = Self.parseSRT(content)
                log("[Subtitle] SRT 파싱 완료 — 추출된 텍스트 길이: \(text.count)자")
                if !text.isEmpty {
                    log("[Subtitle] ✅ 로컬 자막 추출 성공 (SRT) — 파일: \(file)")
                    return text
                }
                log("[Subtitle] ⚠️ 로컬 SRT에서 유효한 텍스트 없음")
            }
        }

        log("[Subtitle] ❌ 로컬 자막 없음 → YouTube 다운로드 시도 — videoId: \(videoId)")
        return try await fetchTranscript(videoId: videoId)
    }

    // MARK: - Subtitle Parsing

    static func parseVTT(_ content: String) -> String {
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

    static func parseSRT(_ content: String) -> String {
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
        You are a helpful assistant that summarizes YouTube videos.

        **반드시 모든 내용을 한국어로 답변하세요. 영어 사용 금지.**

        Video Title: \(title)
        Channel: \(channel)

        Transcript:
        \(text.prefix(15000))

        Provide a summary in this exact format:

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
                        throw SummaryError.summaryFailed(detail ?? "API 키가 올바르지 않습니다. 설정에서 API 키를 확인해 주세요.")
                    case 403:
                        throw SummaryError.summaryFailed(detail ?? "API 키에 권한이 없습니다. 설정에서 API 키를 확인해 주세요.")
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
        var chapters: [ChapterInfo] = []

        let lines = response.components(separatedBy: .newlines)
        var foundPoints = false
        var foundChapters = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("개요:") || trimmed.hasPrefix("개요 :") {
                let idx = trimmed.hasPrefix("개요:") ? 3 : 4
                overview = String(trimmed.dropFirst(idx)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("핵심 포인트:") || trimmed.hasPrefix("핵심 포인트 :") {
                foundPoints = true
                foundChapters = false
            } else if trimmed.hasPrefix("챕터:") || trimmed.hasPrefix("챕터 :") || trimmed.hasPrefix("Chapters:") || trimmed.hasPrefix("chapters:") {
                foundChapters = true
                foundPoints = false
            } else if foundPoints, trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                let point = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !point.isEmpty { keyPoints.append(point) }
            } else if foundChapters {
                if let chapter = Self.parseChapterLine(trimmed) {
                    chapters.append(chapter)
                }
            } else if !foundPoints, !foundChapters, !overview.isEmpty, !trimmed.isEmpty, !trimmed.hasPrefix("핵심"), !trimmed.hasPrefix("챕터") {
                if trimmed.range(of: "^[\\s\\*\\-]*$", options: .regularExpression) == nil {
                    overview += " " + trimmed
                }
            }
        }

        if overview.isEmpty {
            overview = String(response.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return SummaryResult(overview: overview, keyPoints: keyPoints, chapters: chapters, provider: "")
    }

    // MARK: - Chapter Parsing (외부 접근 가능)

    static func parseChapterLineStatic(_ line: String) -> ChapterInfo? {
        return parseChapterLine(line)
    }

    private static func parseChapterLine(_ line: String) -> ChapterInfo? {
        let patterns = [
            #"^\d+[\.\)]\s*\[?(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–~]\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+)$"#,
            #"^[\-\*•]\s*\[?(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–~]\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+)$"#,
            #"^\[?(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–~]\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let startStr = String(line[Range(match.range(at: 1), in: line)!])
                let endStr = String(line[Range(match.range(at: 2), in: line)!])
                let title = String(line[Range(match.range(at: 3), in: line)!]).trimmingCharacters(in: .whitespaces)
                let startTime = Self.parseTimeToSeconds(startStr)
                let endTime = Self.parseTimeToSeconds(endStr)
                if !title.isEmpty {
                    return ChapterInfo(title: title, startTime: startTime, endTime: endTime)
                }
            }
        }
        return nil
    }

    private static func parseTimeToSeconds(_ time: String) -> Double {
        let parts = time.split(separator: ":").map { Double($0) ?? 0 }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return parts.first ?? 0
        }
    }
}
