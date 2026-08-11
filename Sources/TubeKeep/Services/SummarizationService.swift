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

    func summarize(videoId: String, title: String, channel: String, apiKey: String, progress: (@Sendable (String) -> Void)? = nil) async throws -> SummaryResult {
        let text = try await fetchTranscript(videoId: videoId, progress: progress)
        progress?("요약 생성 중...")
        return try await generateSummary(text: text, title: title, channel: channel, apiKey: apiKey)
    }

    func summarizeVideo(videoId: String, title: String, channel: String, openRouterAPIKey: String, geminiAPIKey: String, progress: (@Sendable (String) -> Void)? = nil) async throws -> SummaryResult {
        AITaskTracker.shared.begin()
        defer { AITaskTracker.shared.end() }
        log("[AI Fallback] 요약 시작 — videoId: \(videoId), title: \(title)")

        // DB 캐시 확인 — 기존 요약이 있으면 바로 반환
        progress?("캐시 확인 중...")
        if let cached = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
           let summary = cached.summary, !summary.isEmpty {
            log("[AI Fallback] ✅ DB 캐시 히트 — videoId: \(videoId)")
            DebugLogManager.shared?.push(.CACHE, category: "AI", message: "요약 DB 캐시 히트", meta: ["videoId": videoId, "cost_saved": true])
            let chapters: [ChapterInfo] = {
                guard let data = cached.chapters else { return [] }
                return (try? JSONDecoder().decode([ChapterInfo].self, from: data)) ?? []
            }()
            return SummaryResult(overview: summary, keyPoints: [], chapters: chapters, provider: "cached")
        }

        log("[AI Fallback] 사용 가능한 서비스 — Gemini: \(geminiAPIKey.isEmpty ? "없음" : "있음"), OpenRouter: \(openRouterAPIKey.isEmpty ? "없음" : "있음"), yTeaser: 항상 사용")

        let steps: [LLMChainStep<SummaryResult>] = [
            LLMChainStep(provider: "Gemini", isAvailable: !geminiAPIKey.isEmpty) {
                let result = try await self.summarize(videoId: videoId, title: title, channel: channel, apiKey: geminiAPIKey, progress: progress)
                return result
            },
            LLMChainStep(provider: "OpenRouter", isAvailable: !openRouterAPIKey.isEmpty) {
                self.log("[AI Fallback] 2순위: OpenRouter 시도 — videoId: \(videoId)")
                let text = try await self.fetchTranscript(videoId: videoId, progress: progress)
                self.log("[AI Fallback] 자막 추출 완료 — 길이: \(text.count)자")
                progress?("요약 생성 중...")
                let service = OpenRouterService()
                let result = try await service.generateSummary(transcript: text, title: title, channel: channel, apiKey: openRouterAPIKey)
                return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "OpenRouter")
            },
            LLMChainStep(provider: "yTeaser", isAvailable: true) {
                self.log("[AI Fallback] 3순위: yTeaser 시도 — videoId: \(videoId)")
                return try await self.summarizeWithYTeaser(videoId: videoId, title: title, channel: channel)
            },
        ]

        log("[AI Fallback] 체인 실행 — videoId: \(videoId)")
        guard let result = await LLMChainExecutor.run(
            steps,
            logSkipped: { provider in
                self.log("[AI Fallback] \(provider) 키 없음/결과 미검증 → 다음 단계 — videoId: \(videoId)")
            },
            logFailed: { provider, error in
                self.log("[AI Fallback] ❌ \(provider) 실패(\(error.localizedDescription)) → 다음 단계 — videoId: \(videoId)")
            }
        ) else {
            log("[AI Fallback] ❌ 모든 AI 요약 서비스 실패 — videoId: \(videoId)")
            throw SummaryError.apiUnavailable("모든 AI 요약 서비스를 사용할 수 없습니다. 설정에서 API 키를 확인해 주세요.")
        }

        log("[AI Fallback] ✅ \(result.provider) 성공 — videoId: \(videoId)")
        return SummaryResult(overview: result.output.overview, keyPoints: result.output.keyPoints, chapters: result.output.chapters, provider: result.provider)
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }

    private func saveTranscriptToDB(videoId: String, transcript: String, language: String, source: String? = nil) {
        log("[Subtitle] DB 저장 시작 — videoId: \(videoId), 언어: \(language), 길이: \(transcript.count)자")
        var data = DatabaseManager.shared.loadVideoAIData(videoId: videoId) ?? VideoAIData(videoId: videoId)
        data.transcript = transcript
        data.transcriptLanguage = language
        data.subtitleSource = source
        DatabaseManager.shared.saveVideoAIData(data)
        log("[Subtitle] ✅ 자막 DB 저장 완료 — videoId: \(videoId)")
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

    private static func runProcess(arguments: [String]) async throws -> Int32 {
        let box = ProcessBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                let process = Process()
                box.process = process
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = arguments
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.terminationHandler = { p in
                    continuation.resume(returning: p.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            box.process?.terminate()
        }
    }

    private func fetchTranscript(videoId: String, progress: (@Sendable (String) -> Void)? = nil) async throws -> String {
        log("[Subtitle] 자막 가져오기 시작 — videoId: \(videoId)")
        
        // DB에서 캐시된 자막 확인
        log("[Subtitle] DB에서 캐시 확인 중 — videoId: \(videoId)")
        if let cached = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
           let transcript = cached.transcript, !transcript.isEmpty {
            log("[Subtitle] ✅ DB에서 캐시된 자막 로드 성공 — videoId: \(videoId), 길이: \(transcript.count)자")
            return transcript
        }
        log("[Subtitle] ❌ DB에 캐시된 자막 없음 — videoId: \(videoId)")

        progress?("자막 다운로드 중...")
        let videoURL = "https://www.youtube.com/watch?v=\(videoId)"
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("tubekeep_subs_\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        log("[Subtitle] YouTube 자막 다운로드 시작 — videoId: \(videoId)")
        log("[Subtitle] 임시 디렉토리: \(tmpDir.path)")
        let subLangs = LanguageService.subtitleLanguages
        #if DEBUG
        Task { @MainActor in DebugLogManager.shared?.append("[Subtitle] --sub-langs: \(subLangs)") }
        #endif
        let outputTemplate = tmpDir.appendingPathComponent("%(id)s.%(ext)s").path
        let exitCode = try await Self.runProcess(
            arguments: [
                Constants.ytDlpPath,
                "--write-subs",
                "--sub-langs", subLangs,
                "--skip-download",
                "--no-warnings",
                "-o", outputTemplate,
            ] + [videoURL]
        )
        log("[Subtitle] yt-dlp 종료 코드: \(exitCode)")

        let files = (try? fm.contentsOfDirectory(atPath: tmpDir.path)) ?? []
        log("[Subtitle] 다운로드된 파일 수: \(files.count)")
        if files.isEmpty {
            log("[Subtitle] ⚠️ YouTube 자막 없음 — videoId: \(videoId)")
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
                    saveTranscriptToDB(videoId: videoId, transcript: text, language: "en", source: "downloaded")
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
                    saveTranscriptToDB(videoId: videoId, transcript: text, language: "en", source: "downloaded")
                    return text
                }
                log("[Subtitle] ⚠️ SRT에서 유효한 텍스트 없음")
            }
        }
        log("[Subtitle] ❌ 유효한 자막 없음 — videoId: \(videoId)")

        // Whisper fallback: yt-dlp 자막 실패 시 음성 인식
        let settings = Settings.loadSettings()
        if settings.enableWhisperTranscription {
            log("[Subtitle] Whisper fallback 시도 — videoId: \(videoId)")
            progress?("Whisper 자막 생성 중...")
            let whisperService = WhisperService.shared
            let modelSize = settings.whisperModelSize
            if whisperService.isModelDownloaded(modelSize) {
                do {
                    let audioURL = try await downloadAudio(videoId: videoId)
                    log("[Subtitle] Whisper 오디오 다운로드 완료 — \(audioURL.path)")

                    var transcriptText = ""
                    let cues = try await whisperService.transcribe(
                        audioPath: audioURL.path,
                        modelSize: modelSize,
                        progressHandler: { msg in Task { await self.log("[Subtitle] Whisper 진행: \(msg)") } }
                    )
                    transcriptText = cues.map(\.text).joined(separator: " ")
                    try? FileManager.default.removeItem(at: audioURL)

                    if !transcriptText.isEmpty {
                        log("[Subtitle] ✅ Whisper 자막 생성 성공 — videoId: \(videoId), 길이: \(transcriptText.count)자")
                        saveTranscriptToDB(videoId: videoId, transcript: transcriptText, language: LanguageService.systemLanguageCode, source: "whisper")
                        return transcriptText
                    }
                    log("[Subtitle] ⚠️ Whisper 자막이 비어 있음 — videoId: \(videoId)")
                } catch {
                    log("[Subtitle] ❌ Whisper fallback 실패 — videoId: \(videoId), error: \(error.localizedDescription)")
                }
            } else {
                log("[Subtitle] ⚠️ Whisper 모델 미설치 — modelSize: \(modelSize)")
            }
        }

        throw SummaryError.noSubtitle
    }

    private func downloadAudio(videoId: String) async throws -> URL {
        let videoURL = "https://www.youtube.com/watch?v=\(videoId)"
        let tmpDir = FileManager.default.temporaryDirectory
        let outputURL = tmpDir.appendingPathComponent("tubekeep_whisper_\(videoId).wav")

        let exitCode = try await Self.runProcess(arguments: [
            Constants.ytDlpPath,
            "-x", "--audio-format", "wav",
            "--no-warnings",
            "-o", outputURL.path,
        ] + [videoURL])

        guard exitCode == 0, FileManager.default.fileExists(atPath: outputURL.path) else {
            throw SummaryError.transcriptionFailed("오디오 다운로드 실패 (exit: \(exitCode))")
        }
        return outputURL
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
            var seenTiming = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if trimmed.contains("-->") { seenTiming = true; continue }
                if !seenTiming, Int(trimmed) != nil { continue }
                textLines.append(trimmed)
            }
        }
        return textLines.joined(separator: " ")
    }

    // MARK: - LLM Summary

    private func generateSummary(text: String, title: String, channel: String, apiKey: String) async throws -> SummaryResult {
        let prompt = LLMPrompts.summary(transcript: text, title: title, channel: channel)

        let response: String
        do {
            response = try await GeminiService().query(prompt: prompt, apiKey: apiKey)
        } catch let geminiError as GeminiError {
            throw Self.mapGeminiError(geminiError)
        } catch {
            throw SummaryError.apiUnavailable(error.localizedDescription)
        }
        let result = SummaryParser.parse(response)
        return SummaryResult(overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: "")
    }

    private static func mapGeminiError(_ error: GeminiError) -> SummaryError {
        switch error {
        case .quotaExceeded(let detail):
            return .summaryFailed("요청 한도 초과: \(detail ?? "50회 한도 초과")")
        case .apiError(let code, let detail):
            switch code {
            case 400: return .summaryFailed(detail ?? "API 키가 올바르지 않습니다. 설정에서 API 키를 확인해 주세요.")
            case 403: return .summaryFailed(detail ?? "API 키에 권한이 없습니다. 설정에서 API 키를 확인해 주세요.")
            default: return .summaryFailed(detail ?? "Gemini API 오류 (HTTP \(code))")
            }
        case .parsingFailed: return .summaryFailed("Gemini API 응답 파악 실패")
        case .connectionFailed: return .apiUnavailable("Gemini API에 연결할 수 없습니다.")
        case .invalidResponse: return .apiUnavailable("Gemini API 응답이 없습니다")
        }
    }

    private static func parseAPIError(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return nil }
        return message
    }
}
