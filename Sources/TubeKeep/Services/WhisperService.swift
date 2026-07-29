import Foundation
import AppKit

final class WhisperService: @unchecked Sendable {
    private func log(_ message: String) {
        print("[Whisper] \(message)")
        #if DEBUG
        DebugLogManager.shared?.append("[Whisper] \(message)")
        #endif
    }
    static let shared = WhisperService()

    enum WhisperError: LocalizedError {
        case whisperNotFound
        case ffmpegNotFound
        case modelNotFound(String)
        case audioExtractionFailed(String)
        case transcriptionFailed(String)
        case modelDownloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .whisperNotFound: return "whisper-cli 바이너리를 찾을 수 없습니다"
            case .ffmpegNotFound: return "ffmpeg를 찾을 수 없습니다"
            case .modelNotFound: return "선택한 Whisper 모델이 설치되지 않았습니다.\nSettings에서 먼저 다운로드해주세요."
            case .audioExtractionFailed(let msg): return "오디오 추출 실패: \(msg)"
            case .transcriptionFailed(let msg): return "자막 생성 실패: \(msg)"
            case .modelDownloadFailed(let msg): return "모델 다운로드 실패: \(msg)"
            }
        }
    }

    var modelsDir: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TubeKeep/whisper-models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    func modelPath(for size: String) -> String {
        "\(modelsDir)/ggml-\(size).bin"
    }

    func isModelDownloaded(_ size: String) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: size))
    }

    func downloadModel(size: String, progressHandler: @escaping @Sendable (String) -> Void, numericProgress: (@Sendable (Double) -> Void)? = nil, force: Bool = false) async throws {
        let dest = modelPath(for: size)
        if !force, FileManager.default.fileExists(atPath: dest) { return }
        try Task.checkCancellation()

        let url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(size).bin"
        progressHandler("모델 다운로드 중 (\(size))...")

        guard let downloadURL = URL(string: url) else {
            throw WhisperError.modelDownloadFailed("잘못된 URL: \(url)")
        }

        let tmpDest = dest + ".download"
        if FileManager.default.fileExists(atPath: tmpDest) {
            try? FileManager.default.removeItem(atPath: tmpDest)
        }
        FileManager.default.createFile(atPath: tmpDest, contents: nil)

        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: tmpDest))
        defer { try? fileHandle.close() }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: sessionConfig)
        defer { session.invalidateAndCancel() }

        try Task.checkCancellation()

        let (bytes, response) = try await session.bytes(from: downloadURL)
        let total = Int(response.expectedContentLength)
        var downloaded = 0
        let bufferSize = 256 * 1024
        var buffer = Data()
        buffer.reserveCapacity(bufferSize)

        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= bufferSize {
                try fileHandle.write(contentsOf: buffer)
                downloaded += buffer.count
                buffer.removeAll(keepingCapacity: true)
                if let numericProgress, total > 0 {
                    numericProgress(Double(downloaded) / Double(total))
                }
            }
        }
        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
        }

        try fileHandle.close()

        try? FileManager.default.removeItem(atPath: dest)
        try FileManager.default.moveItem(atPath: tmpDest, toPath: dest)
    }

    func extractAudio(videoPath: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: Constants.ffmpegPath) else {
            log("ffmpeg not found at: \(Constants.ffmpegPath)")
            throw WhisperError.ffmpegNotFound
        }
        let tmp = FileManager.default.temporaryDirectory
        let outputPath = tmp.appendingPathComponent("tubekeep_audio_\(UUID().uuidString.prefix(8)).wav").path
        let stderrURL = tmp.appendingPathComponent("ffmpeg_err_\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: stderrURL) }
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.ffmpegPath)
        process.arguments = [
            "-y", "-i", videoPath,
            "-vn", "-acodec", "pcm_s16le",
            "-ar", "16000", "-ac", "1",
            outputPath,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrHandle
        log("ffmpeg extract: \(videoPath) → \(outputPath)")
        try process.run()
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                try? stderrHandle.close()
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        try? stderrHandle.close()
        guard process.terminationStatus == 0 else {
            let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? "unknown"
            log("ffmpeg exit code \(process.terminationStatus): \(stderr.prefix(300))")
            throw WhisperError.audioExtractionFailed(stderr)
        }
        log("ffmpeg OK (\(outputPath))")
        return outputPath
    }

    func transcribe(audioPath: String, modelSize: String, progressHandler: @escaping @Sendable (String) -> Void) async throws -> [SubtitleCue] {
        let binary = Constants.whisperPath
        log("binary: \(binary)")
        guard FileManager.default.fileExists(atPath: binary) else {
            log("binary not found: \(binary)")
            throw WhisperError.whisperNotFound
        }

        let model = modelPath(for: modelSize)
        log("model: \(model) (exists: \(FileManager.default.fileExists(atPath: model)))")
        if !FileManager.default.fileExists(atPath: model) {
            log("model not found, please download in Settings > AI > Whisper")
            throw WhisperError.modelNotFound(model)
        }

        let tmp = FileManager.default.temporaryDirectory
        let srtOutput = tmp.appendingPathComponent("tubekeep_whisper_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: "\(srtOutput).srt") }

        let stderrURL = tmp.appendingPathComponent("whisper_err_\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: stderrURL) }
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        let lang = Locale.current.language.languageCode?.identifier
        process.arguments = [
            "--model", model,
            "--file", audioPath,
            "-osrt",
            "-of", srtOutput,
        ]
        if let lang, lang != "en" {
            process.arguments! += ["--language", lang]
        }

        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrHandle

        log("running: \(binary) --model \(model) --file \(audioPath) -osrt -of \(srtOutput)")
        try process.run()

        let startTime = Date()
        let timerTask = Task { [progressHandler] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let elapsed = Date().timeIntervalSince(startTime)
                progressHandler("자막 생성 중... \(Self.formatTime(elapsed)) 경과")
            }
        }
        defer { timerTask.cancel() }

        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                try? stderrHandle.close()
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        try? stderrHandle.close()

        let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        log("exit code: \(process.terminationStatus)")
        if !stderr.isEmpty {
            log("stderr (last 500 chars): \(stderr.suffix(500))")
        }

        guard process.terminationStatus == 0 else {
            log("failed with code \(process.terminationStatus)")
            throw WhisperError.transcriptionFailed(stderr)
        }

        let srtPath = "\(srtOutput).srt"
        guard FileManager.default.fileExists(atPath: srtPath) else {
            log("SRT not found at: \(srtPath)")
            throw WhisperError.transcriptionFailed("SRT 파일이 생성되지 않았습니다")
        }

        let srtContent = try String(contentsOfFile: srtPath, encoding: .utf8)
        log("SRT content length: \(srtContent.count) chars")
        let cues = parseSRT(srtContent)

        if cues.isEmpty {
            log("parsed 0 cues from SRT")
            throw WhisperError.transcriptionFailed("자막을 파싱할 수 없습니다")
        }

        log("success: \(cues.count) cues")
        return cues
    }

    private func parseSRT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard lines.count >= 2 else { continue }
            guard let timingLine = lines.first(where: { $0.contains("-->") }) else { continue }
            let parts = timingLine.components(separatedBy: " --> ")
            guard parts.count == 2 else { continue }
            let start = parseSRTTime(parts[0])
            let end = parseSRTTime(parts[1])
            var seenTiming = false
            let text = lines.filter { line in
                if line.contains("-->") { seenTiming = true; return false }
                if !seenTiming, Int(line) != nil { return false }
                return true
            }.joined(separator: " ")
            if !text.isEmpty {
                cues.append(SubtitleCue(startTime: start, endTime: end, text: cleanText(text)))
            }
        }
        return cues
    }

    private func parseSRTTime(_ string: String) -> Double {
        let clean = string.trimmingCharacters(in: .whitespaces)
        let parts = clean.components(separatedBy: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 0
            return h * 3600 + m * 60 + s
        }
        return 0
    }

    private func cleanText(_ text: String) -> String {
        var result = text
        let entities = [
            "&amp;": "&", "&gt;": ">", "&lt;": "<",
            "&quot;": "\"", "&#39;": "'", "&nbsp;": " ", "&apos;": "'",
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        result = result.replacingOccurrences(of: "♪", with: "")
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.replacingOccurrences(of: "\r", with: "")
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
