import Foundation
import AVFoundation

extension Notification.Name {
    static let podcastPlaybackFinished = Notification.Name("podcastPlaybackFinished")
}

@MainActor
final class PodcastService: NSObject, AVAudioPlayerDelegate {
    static let shared = PodcastService()

    private let openRouterService = OpenRouterService()
    private let databaseManager = DatabaseManager.shared
    private var audioPlayer: AVAudioPlayer?
    private var currentVideoId: String?
    private var playCompletion: ((Bool) -> Void)?

    // 한국어 음성 식별자
    private static let maleVoiceId = "com.apple.eloquence.ko-KR.Reed"
    private static let femaleVoiceId = "com.apple.voice.super-compact.ko-KR.Yuna"

    enum PodcastError: LocalizedError {
        case noTranscript
        case scriptGenerationFailed(String)
        case ttsFailed(String)
        case fileOperationFailed(String)
        case podcastNotFound
        case audioMergeFailed(String)

        var errorDescription: String? {
            switch self {
            case .noTranscript: return "자막을 찾을 수 없습니다. 팟캐스트를 생성하려면 자막이 필요합니다."
            case let .scriptGenerationFailed(msg): return "대화 스크립트 생성 실패: \(msg)"
            case let .ttsFailed(msg): return "음성 변환 실패: \(msg)"
            case let .fileOperationFailed(msg): return "파일 작업 실패: \(msg)"
            case .podcastNotFound: return "팟캐스트 파일을 찾을 수 없습니다."
            case let .audioMergeFailed(msg): return "오디오 합치기 실패: \(msg)"
            }
        }
    }

    // MARK: - Public

    func generatePodcast(
        videoId: String,
        title: String,
        channel: String,
        transcript: String,
        openRouterAPIKey: String
    ) async throws -> PodcastResult {
        log("[Podcast] 팟캐스트 생성 시작 — videoId: \(videoId)")

        // 1. 대화 스크립트 생성
        let script = try await generateScript(
            transcript: transcript,
            title: title,
            channel: channel,
            openRouterAPIKey: openRouterAPIKey
        )
        log("[Podcast] 대화 스크립트 생성 완료 — 세그먼트: \(script.segments.count)개")

        // 2. 출력 디렉토리 생성
        let outputDir = podcastDirectory(for: videoId)
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        // 3. 세그먼트별로 병렬 TTS 생성 (남성/여성 음성 분리)
        let ttsService = TTSService()
        let tempDir = (outputDir as NSString).appendingPathComponent("temp")
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let ttsEngine: TTSEngine = {
            guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
                  let data = json.data(using: .utf8),
                  let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
                return .apple
            }
            return settings.ttsEngine
        }()

        log("[Podcast] 병렬 TTS 시작 — 세그먼트: \(script.segments.count)개, 엔진: \(ttsEngine.displayName)")

        let segmentURLs: [URL] = await withTaskGroup(of: (Int, URL?).self, returning: [URL].self) { group in
            for (index, segment) in script.segments.enumerated() {
                group.addTask {
                    let segURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("seg_\(index).aiff"))
                    let voiceId = segment.speaker.contains("A") ? ttsEngine.maleVoice : ttsEngine.femaleVoice
                    let cleanText = segment.text
                        .replacingOccurrences(of: #"^진행자[AB]\s*:\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"^\[진행자[AB]\]\s*"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    do {
                        try await ttsService.synthesizeToFile(
                            text: cleanText,
                            outputURL: segURL,
                            engine: ttsEngine,
                            voiceIdentifier: voiceId,
                            rate: 0.55
                        )
                        return (index, segURL)
                    } catch {
                        return (index, nil)
                    }
                }
            }

            var results: [(Int, URL?)] = []
            for await result in group {
                results.append(result)
            }
            return results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }

        log("[Podcast] 세그먼트 TTS 완료 — 개수: \(segmentURLs.count)")

        // 4. 세그먼트 오디오를 하나로 합치기 (AVAudioFile append)
        let audioPath = (outputDir as NSString).appendingPathComponent("\(videoId)_full.aiff")
        let audioURL = URL(fileURLWithPath: audioPath)
        try concatenateAudioFiles(urls: segmentURLs, outputURL: audioURL)
        log("[Podcast] 오디오 합치기 완료 — 경로: \(audioPath)")

        // 5. 임시 파일 정리
        try? FileManager.default.removeItem(atPath: tempDir)

        // 6. 스크립트 JSON 저장
        let scriptPath = (outputDir as NSString).appendingPathComponent("\(videoId)_script.json")
        let scriptData = try JSONEncoder().encode(script)
        try scriptData.write(to: URL(fileURLWithPath: scriptPath))
        log("[Podcast] 스크립트 저장 완료 — 경로: \(scriptPath)")

        // 7. DB 업데이트
        databaseManager.updatePodcastPath(videoId: videoId, podcastPath: outputDir)
        log("[Podcast] DB 업데이트 완료 — videoId: \(videoId)")

        // 8. 오디오 길이 계산
        let fullText = script.segments.map { $0.text }.joined(separator: " ")
        let duration = estimateAudioDuration(text: fullText)
        log("[Podcast] 팟캐스트 생성 완료 — 길이: \(Int(duration))초")

        return PodcastResult(
            audioPath: audioPath,
            script: script,
            duration: duration,
            engineName: ttsEngine.displayName
        )
    }

    func deletePodcast(videoId: String) throws {
        // 재생 중이면 먼저 중지
        if currentVideoId == videoId {
            stopPodcast()
        }

        let dir = podcastDirectory(for: videoId)
        if FileManager.default.fileExists(atPath: dir) {
            try FileManager.default.removeItem(atPath: dir)
            log("[Podcast] 팟캐스트 디렉토리 삭제 — videoId: \(videoId)")
        }
        databaseManager.updatePodcastPath(videoId: videoId, podcastPath: nil)
        log("[Podcast] DB 업데이트 완료 — podcastPath: nil")
    }

    nonisolated func getPodcastPath(videoId: String) -> String? {
        guard let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId) else { return nil }
        return data.podcastPath
    }

    nonisolated func getPodcastScript(videoId: String) -> PodcastScript? {
        guard let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
              let path = data.podcastPath else { return nil }
        let scriptPath = (path as NSString).appendingPathComponent("\(videoId)_script.json")
        guard let scriptData = try? Data(contentsOf: URL(fileURLWithPath: scriptPath)) else { return nil }
        return try? JSONDecoder().decode(PodcastScript.self, from: scriptData)
    }

    // MARK: - Playback

    func playPodcast(videoId: String, completion: ((Bool) -> Void)? = nil) throws {
        guard let path = getPodcastPath(videoId: videoId) else {
            throw PodcastError.podcastNotFound
        }

        let audioPath = (path as NSString).appendingPathComponent("\(videoId)_full.aiff")
        guard FileManager.default.fileExists(atPath: audioPath) else {
            throw PodcastError.podcastNotFound
        }

        // 기존 재생 정지
        audioPlayer?.stop()

        let url = URL(fileURLWithPath: audioPath)
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        currentVideoId = videoId
        playCompletion = completion
        log("[Podcast] 재생 시작 — videoId: \(videoId)")
    }

    func pausePodcast() {
        audioPlayer?.pause()
        log("[Podcast] 일시정지")
    }

    func resumePodcast() {
        audioPlayer?.play()
        log("[Podcast] 재개")
    }

    func stopPodcast() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentVideoId = nil
        playCompletion = nil
        log("[Podcast] 정지")
    }

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.currentVideoId = nil
            self.playCompletion?(flag)
            self.playCompletion = nil
            NotificationCenter.default.post(name: .podcastPlaybackFinished, object: nil)
            #if DEBUG
            DebugLogManager.shared?.append("[Podcast] 재생 완료")
            #endif
        }
    }

    // MARK: - Private

    private func generateScript(
        transcript: String,
        title: String,
        channel: String,
        openRouterAPIKey: String
    ) async throws -> PodcastScript {
        let prompt = """
        다음 YouTube 영상의 자막을 분석하여 2인 팟캐스트 대화를 작성해 주세요.

        **반드시 모든 내용을 한국어로 답변하세요. 영어 사용 금지.**

        영상 제목: \(title)
        채널: \(channel)

        규칙:
        1. 진행자A(남성, 친근한 진행자)와 진행자B(여성, 분석적인 전문가)가 대화
        2. 실제 팟캐스트처럼 자연스럽게 대화로 전달
           - 서로의 말에 리액션 ("맞아요", "그렇죠", "흥미롭네요")
           - 질문과 답변 형태로 내용 전달
           - 가볍게 웃음이나 감탄사 포함 ("하하", "와", "그건 정말")
        3. 각 대사는 1~2문장으로 간결하게 (긴 대사 금지)
        4. 총 20~30개 세그먼트
        5. 첫 번째 세그먼트는 인사말로 시작, 마지막은 마무리 인사

        출력 형식 (JSON 배열만 출력하세요):
        [{"speaker": "진행자A", "text": "안녕하세요, 오늘은..."}, {"speaker": "진행자B", "text": "네, 정말 흥미로운 내용이네요."}]

        자막 내용:
        \(transcript.prefix(12000))
        """

        let response = try await openRouterService.chatCompletionForPodcast(
            prompt: prompt,
            apiKey: openRouterAPIKey
        )

        return try parseScriptResponse(response)
    }

    private func parseScriptResponse(_ response: String) throws -> PodcastScript {
        log("[Podcast] 파싱 시작 — 응답 길이: \(response.count)")

        // JSON 배열 부분만 추출
        var jsonString: String = ""

        // 1. 마크다운 코드 블록에서 JSON 추출 (```json ... ``` 또는 ``` ... ```)
        let codeBlockPatterns = ["```json", "```"]
        for pattern in codeBlockPatterns {
            if let codeBlockStart = response.range(of: pattern),
               let codeBlockEnd = response.range(of: "```", range: codeBlockStart.upperBound..<response.endIndex) {
                jsonString = String(response[codeBlockStart.upperBound..<codeBlockEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !jsonString.isEmpty {
                    log("[Podcast] 코드 블록에서 JSON 추출 — 길이: \(jsonString.count)")
                    break
                }
            }
        }

        // 2. 직접 JSON 배열 검색 (텍스트에서 [로 시작하여 ]로 끝나는 부분)
        if jsonString.isEmpty {
            if let start = response.firstIndex(of: "["),
               let end = response.lastIndex(of: "]") {
                jsonString = String(response[start...end])
                log("[Podcast] 직접 JSON 배열 추출 — 길이: \(jsonString.count)")
            }
        }

        // 3. 중괄호로 감싸진 JSON 객체인 경우 배열로 변환 시도
        if jsonString.isEmpty, let start = response.firstIndex(of: "{"), let end = response.lastIndex(of: "}") {
            let jsonObject = String(response[start...end])
            jsonString = "[\(jsonObject)]"
            log("[Podcast] JSON 객체를 배열로 변환 — 길이: \(jsonString.count)")
        }

        // 4. 여러 JSON 객체를 배열로 변환 시도 (逗留로 구분된 경우)
        if jsonString.isEmpty {
            var objects: [String] = []
            var searchRange = response.startIndex..<response.endIndex
            while let start = response.range(of: "{", range: searchRange) {
                if let end = response.range(of: "}", range: start.upperBound..<response.endIndex) {
                    let obj = String(response[start.lowerBound...end.upperBound])
                    objects.append(obj)
                    searchRange = end.upperBound..<response.endIndex
                } else {
                    break
                }
            }
            if !objects.isEmpty {
                jsonString = "[\(objects.joined(separator: ","))]"
                log("[Podcast] 여러 JSON 객체를 배열로 변환 — 길이: \(jsonString.count)")
            }
        }

        guard !jsonString.isEmpty else {
            log("[Podcast] ❌ JSON 형식을 찾을 수 없음 — 응답: \(response.prefix(200))")
            throw PodcastError.scriptGenerationFailed("JSON 형식을 찾을 수 없습니다")
        }

        // JSON 괄호 균형 맞추기 ( 잘린 응답 처리)
        jsonString = balanceBrackets(jsonString)

        // JSON 정리 (불필요한 문자 제거)
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        log("[Podcast] 정리된 JSON — 길이: \(cleanedJSON.count), 앞: \(cleanedJSON.prefix(200)), 뒤: \(cleanedJSON.suffix(200))")

        guard let data = cleanedJSON.data(using: .utf8) else {
            log("[Podcast] ❌ JSON 데이터 변환 실패")
            throw PodcastError.scriptGenerationFailed("JSON 데이터 변환 실패")
        }

        do {
            let segments = try JSONDecoder().decode([PodcastSegment].self, from: data)
            guard segments.count >= 5 else {
                log("[Podcast] ❌ 세그먼트 부족 — 개수: \(segments.count) (최소 5개 필요)")
                throw PodcastError.scriptGenerationFailed("세그먼트가 너무 적습니다 (\(segments.count)개)")
            }
            log("[Podcast] ✅ 세그먼트 파싱 성공 — 개수: \(segments.count)")
            return PodcastScript(segments: segments)
        } catch let error as PodcastError {
            throw error
        } catch {
            // 실패 시 JSON 복구 시도 ( 쉼표 제거, 닫기 괄호 추가 등)
            log("[Podcast] ⚠️ JSON 디코딩 실패 — 복구 시도: \(error.localizedDescription)")
            if let recovered = tryRecoverJSON(cleanedJSON) {
                let segments = try JSONDecoder().decode([PodcastSegment].self, from: recovered)
                log("[Podcast] ✅ 복구 후 세그먼트 파싱 성공 — 개수: \(segments.count)")
                return PodcastScript(segments: segments)
            }
            throw PodcastError.scriptGenerationFailed("세그먼트 파싱 실패: \(error.localizedDescription)")
        }
    }

    private func balanceBrackets(_ json: String) -> String {
        var result = json
        let openBrackets = json.filter { $0 == "[" }.count
        let closeBrackets = json.filter { $0 == "]" }.count
        let openBraces = json.filter { $0 == "{" }.count
        let closeBraces = json.filter { $0 == "}" }.count

        if openBraces > closeBraces {
            let trailingObjects = String(repeating: "}", count: openBraces - closeBraces)
            if result.hasSuffix(",") {
                result = String(result.dropLast())
            }
            result += trailingObjects
        }
        if openBrackets > closeBrackets {
            result += String(repeating: "]", count: openBrackets - closeBrackets)
        }
        return result
    }

    private func tryRecoverJSON(_ json: String) -> Data? {
        // 1. 쉼표 뒤 닫기 괄호 제거 (trailing comma)
        var fixed = json.replacingOccurrences(of: ",]", with: "]")
        fixed = fixed.replacingOccurrences(of: ",}", with: "}")

        // 2. 이스케이프되지 않은 줄바꿈 문자열 내 제거
        var inString = false
        var escaped = false
        var result = ""
        for char in fixed {
            if char == "\"" && !escaped {
                inString.toggle()
                result.append(char)
            } else if inString && char == "\n" {
                // 문자열 내 줄바꿈 제거
            } else if inString && char == "\\" && !escaped {
                escaped = true
                result.append(char)
            } else {
                escaped = false
                result.append(char)
            }
        }

        // 3. 끝에 ] 없는 경우 추가
        if !result.hasSuffix("]") {
            if result.hasSuffix(",") {
                result = String(result.dropLast())
            }
            result += "]"
        }

        guard let data = result.data(using: .utf8) else { return nil }
        return data
    }

    private func concatenateAudioFiles(urls: [URL], outputURL: URL) throws {
        guard !urls.isEmpty else {
            throw PodcastError.audioMergeFailed("합칠 오디오 파일이 없습니다")
        }

        // 첫 번째 유효한 파일의 포맷으로 출력 파일 생성
        var output: AVAudioFile?
        var outputFormat: AVAudioFormat?

        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else {
                log("[Podcast] ⚠️ 파일 없음 — \(url.lastPathComponent)")
                continue
            }

            let file: AVAudioFile
            do {
                file = try AVAudioFile(forReading: url)
            } catch {
                log("[Podcast] ⚠️ 파일 읽기 실패 — \(url.lastPathComponent): \(error.localizedDescription)")
                continue
            }

            // 빈 파일 건너뛰기
            guard file.length > 0 else {
                log("[Podcast] ⚠️ 빈 파일 건너뛰기 — \(url.lastPathComponent)")
                continue
            }

            let inputFormat = file.processingFormat

            // 출력 파일이 아직 없으면 생성
            if output == nil {
                outputFormat = inputFormat
                output = try AVAudioFile(forWriting: outputURL, settings: inputFormat.settings, commonFormat: inputFormat.commonFormat, interleaved: inputFormat.isInterleaved)
                log("[Podcast] 출력 파일 생성 — 포맷: \(inputFormat), 샘플레이트: \(inputFormat.sampleRate)")
            }

            guard let output = output, let outputFormat = outputFormat else { continue }

            // 포맷이 같으면 직접 복사
            let formatsMatch = inputFormat.sampleRate == outputFormat.sampleRate &&
                               inputFormat.channelCount == outputFormat.channelCount &&
                               inputFormat.commonFormat == outputFormat.commonFormat

            if formatsMatch {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                    log("[Podcast] ⚠️ 버퍼 생성 실패 — \(url.lastPathComponent)")
                    continue
                }
                try file.read(into: buffer)
                try output.write(from: buffer)
            } else {
                // 포맷이 다르면 변환 후 복사
                guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                    log("[Podcast] ⚠️ 오디오 변환기 생성 실패 — \(url.lastPathComponent)")
                    continue
                }

                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                    log("[Podcast] ⚠️ 입력 버퍼 생성 실패 — \(url.lastPathComponent)")
                    continue
                }
                try file.read(into: inputBuffer)

                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(inputBuffer.frameLength)) else {
                    log("[Podcast] ⚠️ 출력 버퍼 생성 실패 — \(url.lastPathComponent)")
                    continue
                }

                var inputProvided = false
                var conversionError: NSError?
                let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                    if !inputProvided {
                        inputProvided = true
                        outStatus.pointee = .haveData
                        return inputBuffer
                    } else {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                }

                if status == .haveData || status == .endOfStream {
                    try output.write(from: outputBuffer)
                } else if let error = conversionError {
                    log("[Podcast] ⚠️ 오디오 변환 실패 — \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            log("[Podcast] 세그먼트 추가 완료 — \(url.lastPathComponent)")
        }

        guard output != nil else {
            throw PodcastError.audioMergeFailed("합친 오디오가 비어있습니다")
        }

        log("[Podcast] 오디오 연결 완료 — 파일 수: \(urls.count)")
    }

    private func podcastDirectory(for videoId: String) -> String {
        let docsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/TubeKeep/Podcasts")
            .path
        return (docsPath as NSString).appendingPathComponent(videoId)
    }

    private func estimateAudioDuration(text: String) -> TimeInterval {
        // 한국어 TTS는 분당 약 200~250자
        let charsPerSecond = 3.5
        return Double(text.count) / charsPerSecond
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}
