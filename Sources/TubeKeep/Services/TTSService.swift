import AVFoundation

@MainActor
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?
    private var isPaused = false
    private var currentUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate, completion: (() -> Void)? = nil) {
        self.completion = completion
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: LanguageService.appleTTSLanguage)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        currentUtterance = utterance

        synthesizer.speak(utterance)
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPaused = false
        currentUtterance = nil
    }

    // MARK: - Engine Selection

    nonisolated func synthesizeToFile(
        text: String,
        outputURL: URL,
        engine: TTSEngine = .apple,
        voiceIdentifier: String? = nil,
        rate: Float = 0.5
    ) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            FileManager.default.createFile(atPath: outputURL.path, contents: Data())
            return
        }

        switch engine {
        case .apple:
            try await synthesizeWithApple(text: text, outputURL: outputURL, voiceIdentifier: voiceIdentifier, rate: rate)
        case .edgeTTS:
            let voice = voiceIdentifier ?? engine.maleVoice
            // rate 0.5 → "+0%", 0.55 → "+10%", 0.6 → "+20%"
            let ratePercent = Int((rate - 0.5) * 200)
            let rateStr = ratePercent >= 0 ? "+\(ratePercent)%" : "\(ratePercent)%"
            try await synthesizeWithEdgeTTS(text: text, outputURL: outputURL, voice: voice, rate: rateStr)
        }
    }

    // MARK: - Apple TTS

    private nonisolated func synthesizeWithApple(
        text: String,
        outputURL: URL,
        voiceIdentifier: String?,
        rate: Float
    ) async throws {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)

        if let voiceId = voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: LanguageService.appleTTSLanguage)
        }
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0

        try? FileManager.default.removeItem(at: outputURL)

        var output: AVAudioFile?

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var isResumed = false

            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    return
                }

                let doneLength: Int
                if pcmBuffer.format.commonFormat == .pcmFormatInt16 || pcmBuffer.format.commonFormat == .pcmFormatInt32 {
                    doneLength = 0
                } else {
                    doneLength = 1
                }

                if pcmBuffer.frameLength <= doneLength {
                    guard !isResumed else { return }
                    isResumed = true
                    continuation.resume()
                } else {
                    do {
                        if output == nil {
                            output = try AVAudioFile(
                                forWriting: outputURL,
                                settings: pcmBuffer.format.settings,
                                commonFormat: pcmBuffer.format.commonFormat,
                                interleaved: pcmBuffer.format.isInterleaved
                            )
                        }
                        try output?.write(from: pcmBuffer)
                    } catch {
                        guard !isResumed else { return }
                        isResumed = true
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Edge TTS (Swift WebSocket - Python 불필요)

    private nonisolated func synthesizeWithEdgeTTS(
        text: String,
        outputURL: URL,
        voice: String,
        rate: String = "+0%"
    ) async throws {
        let mp3URL = outputURL.deletingPathExtension().appendingPathExtension("mp3")

        ttsLog("[EdgeTTS] WebSocket 연결 중 — voice: \(voice), rate: \(rate), text: \(text.prefix(30))...")

        // 순수 Swift WebSocket 클라이언트로 MP3 데이터 수신
        let client = EdgeTTSClient()
        let mp3Data: Data
        do {
            mp3Data = try await client.synthesize(text: text, voice: voice, rate: rate)
        } catch {
            ttsLog("[EdgeTTS] ❌ 실패 — \(error.localizedDescription)")
            throw TTSError.engineError("Edge TTS 실패: \(error.localizedDescription)")
        }

        guard !mp3Data.isEmpty else {
            throw TTSError.engineError("Edge TTS 오디오 데이터 없음")
        }

        ttsLog("[EdgeTTS] ✅ MP3 수신 — \(mp3Data.count) bytes")

        // MP3 데이터를 파일로 저장
        try mp3Data.write(to: mp3URL)

        // MP3를 AIFF로 변환 (기존 세그먼트 합치기와 호환)
        try? FileManager.default.removeItem(at: outputURL)
        try await convertMP3ToAIFF(mp3URL: mp3URL, aiffURL: outputURL)
        try? FileManager.default.removeItem(at: mp3URL)

        ttsLog("[EdgeTTS] ✅ AIFF 변환 완료 — \(outputURL.path)")
    }

    private nonisolated func convertMP3ToAIFF(mp3URL: URL, aiffURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.ffmpegPath)
        process.arguments = [
            "-i", mp3URL.path,
            "-f", "aiff",
            "-y", aiffURL.path
        ]

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TTSError.engineError("MP3→AIFF 변환 실패")
        }
    }
}

// MARK: - Logger

private func ttsLog(_ message: String) {
    #if DEBUG
    Task { @MainActor in
        DebugLogManager.shared?.append(message)
    }
    #endif
}

// MARK: - Errors

enum TTSError: LocalizedError {
    case engineError(String)

    var errorDescription: String? {
        switch self {
        case .engineError(let message): return message
        }
    }
}
