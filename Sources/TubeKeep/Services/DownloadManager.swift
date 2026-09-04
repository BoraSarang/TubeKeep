import Foundation
import AppKit
import ComposableArchitecture
import os

final class DownloadManager: @unchecked Sendable {
    static let shared = DownloadManager()

    private struct ManagerState {
        var settings = Settings()
        var storageDirectory = Constants.defaultStorageDirectory
        var filenameTemplate = Constants.defaultFilenameTemplate
        var pausedItems: Set<UUID> = []
        var canceledItems: Set<UUID> = []
    }

    private let runner = ProcessRunner()
    private let activeLock = OSAllocatedUnfairLock(initialState: [UUID: Process]())
    private let stateLock = OSAllocatedUnfairLock(initialState: ManagerState())

    private init() {}

    func updateSettings(_ newSettings: Settings) {
        stateLock.withLock {
            $0.settings = newSettings
            $0.storageDirectory = newSettings.storageDirectory
            $0.filenameTemplate = newSettings.filenameTemplate
        }
    }

    func startDownload(
        item: DownloadItem,
        progressHandler: @escaping @Sendable (UUID, Double, String) -> Void,
        completionHandler: @escaping @Sendable (UUID, Bool, String?, String?) -> Void,
        logHandler: (@Sendable (UUID, String) -> Void)? = nil
    ) {
        if !BookmarkManager.ensureAccess() {
            let msg = "저장 폴더에 접근할 수 없습니다. 설정에서 저장 폴더를 다시 선택해 주세요."
            DebugLogManager.shared?.append("[ERROR] E-MAC-STOR-1001 다운로드 시작 시 \(msg)")
            completionHandler(item.id, false, nil, msg)
            return
        }

        stateLock.withLock {
            $0.canceledItems.remove(item.id)
            $0.pausedItems.remove(item.id)
        }

        let s = stateLock.withLock { $0.settings }
        let outputDir = s.storageDirectory
        let tmpl = stateLock.withLock { $0.filenameTemplate }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                try Task.checkCancellation()
            } catch { return }
            if stateLock.withLock({ $0.canceledItems.contains(item.id) }) { return }

            Self.cleanupPartialFiles(videoId: item.videoInfo.id, in: outputDir)

            var args = buildDownloadArgs(item: item, outputDir: outputDir, settings: s, filenameTemplate: tmpl)
            #if DEBUG
            let fmt = item.selectedFormat
            Task { @MainActor in
                DebugLogManager.shared?.append("[DownloadManager] selectedFormat id=\(fmt.id) isVideoOnly=\(fmt.isVideoOnly) isAudioOnly=\(fmt.isAudioOnly) height=\(fmt.height) ext=\(fmt.ext)")
                let fmtStr = args.firstIndex(of: "-f").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "unknown"
                DebugLogManager.shared?.append("[DownloadManager] format string: -f \(fmtStr)")
            }
            #endif
            args += ["--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s"]

            let outputPathFile = FileManager.default.temporaryDirectory.appendingPathComponent("tubekeep_output_\(item.id.uuidString).txt").path
            args += ["--print-to-file", "after_move:filepath", outputPathFile]

            let process = Process()
            ProcessRegistry.register(process)
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [Constants.ytDlpPath] + args

            // Include bundled resources in PATH so yt-dlp can find bundled ffmpeg
            var env = ProcessInfo.processInfo.environment
            if let resources = Bundle.main.resourceURL?.path {
                env["PATH"] = "\(resources):\(env["PATH"] ?? "")"
            }
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            activeLock.withLock { $0[item.id] = process }

            defer {
                activeLock.withLock { _ = $0.removeValue(forKey: item.id) }
                try? FileManager.default.removeItem(atPath: outputPathFile)
            }

            do {
                #if DEBUG
                Task { @MainActor in
                    DebugLogManager.shared?.append("[DownloadManager] 프로세스 시작 pid=\(process.processIdentifier)")
                }
                #endif
                try process.run()

                let stdoutHandle = stdoutPipe.fileHandleForReading
                let stderrHandle = stderrPipe.fileHandleForReading
                final class Box: @unchecked Sendable {
                    var lastPercent: Double
                    var lastSpeed = ""
                    init(percent: Double) { lastPercent = percent }
                }
                let box = Box(percent: item.progress)

                stdoutHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    #if DEBUG
                    if !data.isEmpty {
                        let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8>"
                        if !preview.contains("%|") {
                            Task { @MainActor in
                                DebugLogManager.shared?.append("[DownloadManager] stdout RAW[\(data.count)]: \(preview)")
                            }
                        }
                    }
                    #endif
                    guard !data.isEmpty else { return }
                    guard let output = String(data: data, encoding: .utf8) else { return }

                    for line in output.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { continue }
                        let cleaned = trimmed.replacingOccurrences(
                            of: "[download]",
                            with: ""
                        ).trimmingCharacters(in: .whitespaces)
                        let parts = cleaned.components(separatedBy: "|")
                        guard parts.count >= 2 else { continue }

                        let pctRaw = parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                        let spdStr = parts[1].trimmingCharacters(in: .whitespaces)

                        guard let pct = Double(pctRaw) else { continue }
                        if pct != box.lastPercent || !spdStr.isEmpty {
                            box.lastPercent = pct
                            box.lastSpeed = spdStr
                            #if DEBUG
                            if Int(pct) % 5 == 0 || pct >= 100 {
                                Task { @MainActor in
                                    DebugLogManager.shared?.append("[DownloadManager] 진행률 \(pct)%")
                                }
                            }
                            #endif
                            progressHandler(item.id, pct / 100.0, spdStr)
                        }
                    }
                }

                    final class SendableData: @unchecked Sendable {
                        var data = Data()
                    }
                    let buf = SendableData()
                    let stderrLock = NSLock()
                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                        stderrLock.withLock { buf.data.append(data) }
                        for line in output.components(separatedBy: .newlines) {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }
                            logHandler?(item.id, trimmed)
                        }
                    }

                while process.isRunning {
                    if Task.isCancelled {
                        process.terminate()
                        let pid = process.processIdentifier
                        if pid > 0 { kill(pid, SIGKILL) }
                        break
                    }
                    try await Task.sleep(nanoseconds: 300_000_000)
                }
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil

                let errRemaining = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = stderrLock.withLock {
                    buf.data.append(errRemaining)
                    return String(data: buf.data, encoding: .utf8)
                }

                let suppressed = stateLock.withLock {
                    $0.canceledItems.contains(item.id) || $0.pausedItems.contains(item.id)
                }

                #if DEBUG
                Task { @MainActor in
                    DebugLogManager.shared?.append("[DownloadManager] 루프 종료 isCancelled=\(Task.isCancelled) suppressed=\(suppressed) terminationStatus=\(process.terminationStatus)")
                }
                #endif

                if !Task.isCancelled && !suppressed {
                    let actualPath: String? = {
                        let fm = FileManager.default
                        // 1) Try after_move:filepath first
                        let afterMovePath: String? = {
                            guard let data = try? Data(contentsOf: URL(fileURLWithPath: outputPathFile)),
                                  let content = String(data: data, encoding: .utf8)
                            else { return nil }
                            try? fm.removeItem(atPath: outputPathFile)
                            let lines = content.components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            for line in lines.reversed() where Self.isValidMediaFile(line) {
                                return line
                            }
                            return nil
                        }()
                        // 2) Validate: file must exist and be a real media file (ignore .part/.webp/.jpg/.png)
                        if let path = afterMovePath, Self.isValidMediaFile(path) {
                            return path
                        }
                        // 3) Fallback: scan output directory for videoId
                        let folder = Constants.sanitizeFolderName(item.videoInfo.channel)
                        let channelDir = "\(outputDir)/\(folder)"
                        let videoId = item.videoInfo.id
                        guard let files = try? fm.contentsOfDirectory(atPath: channelDir) else { return nil }
                        for file in files where file.contains(videoId) {
                            let path = "\(channelDir)/\(file)"
                            if Self.isValidMediaFile(path) { return path }
                        }
                        return nil
                    }()

                    if let path = actualPath, FileManager.default.fileExists(atPath: path) {
                        #if DEBUG
                        Task { @MainActor in
                            DebugLogManager.shared?.append("[DownloadManager] 완료 처리: status=\(process.terminationStatus) path=\(actualPath ?? "nil")")
                        }
                        #endif
                        if item.includeSubtitles, let mediaPath = actualPath {
                            Self.saveSubtitlesToDB(videoPath: mediaPath)
                        }
                        completionHandler(item.id, true, actualPath, nil)
                        if s.playSoundOnComplete {
                            _ = await MainActor.run {
                                NSSound(named: "Purr")?.play()
                            }
                        }
                    } else {
                        Self.cleanupPartialFiles(videoId: item.videoInfo.id, in: outputDir)
                        completionHandler(item.id, false, nil, ErrorMessageMapper.map(errMsg))
                    }
                }
            } catch {
                if !Task.isCancelled {
                    completionHandler(item.id, false, nil, error.localizedDescription)
                }
            }
        }
    }

    func pauseDownload(itemId: UUID) {
        let process = activeLock.withLock { $0[itemId] }
        guard let p = process, p.isRunning else { return }
        p.interrupt()
        _ = stateLock.withLock { $0.pausedItems.insert(itemId) }
    }

    func resumeDownload(item: DownloadItem,
                        progressHandler: @escaping @Sendable (UUID, Double, String) -> Void,
                        completionHandler: @escaping @Sendable (UUID, Bool, String?, String?) -> Void) {
        stateLock.withLock {
            $0.pausedItems.remove(item.id)
            $0.canceledItems.remove(item.id)
        }
        startDownload(item: item, progressHandler: progressHandler, completionHandler: completionHandler)
    }

    func cancelDownload(itemId: UUID) {
        let process = activeLock.withLock { $0.removeValue(forKey: itemId) }
        stateLock.withLock {
            $0.canceledItems.insert(itemId)
            $0.pausedItems.remove(itemId)
        }
        if let p = process, p.isRunning {
            p.terminate()
            let pid = p.processIdentifier
            if pid > 0 { kill(pid, SIGKILL) }
        }
    }

    @discardableResult
    func cancelAll() -> Int {
        let terminated = activeLock.withLock {
            let keys = Array($0.keys)
            let values = Array($0.values)
            $0.removeAll()
            return (keys: keys, processes: values)
        }
        for p in terminated.processes where p.isRunning {
            p.terminate()
        }
        // 종료 대상 항목을 canceledItems에 등록해 강제 종료된 프로세스가 success 콜백을
        // 발화하지 못하게 차단한다 (suppressed=true 유도).
        stateLock.withLock {
            $0.canceledItems.formUnion(terminated.keys)
            $0.pausedItems.removeAll()
        }
        return terminated.processes.count
    }

    var activeCount: Int {
        activeLock.withLock { $0.count }
    }

    func isPaused(_ itemId: UUID) -> Bool { stateLock.withLock { $0.pausedItems.contains(itemId) } }

    private func buildDownloadArgs(item: DownloadItem, outputDir: String, settings: Settings, filenameTemplate: String) -> [String] {
        let formatId: String = {
            // 오디오만 추출: 영상 스트림은 받지 않고 최고 음질 m4a(원본 AAC)만 —
            // 기존 bestvideo+bestaudio로 영상까지 받아 두 배 다운로드 되는 문제 제거.
            if item.audioOnly {
                return "bestaudio[ext=m4a]/bestaudio/best"
            }
            let id = item.selectedFormat.id
            if id.contains("/") || id.contains("+") {
                return id
            }
            let heightLimit = max(item.selectedFormat.height, settings.defaultResolution)
            if item.selectedFormat.isVideoOnly {
                if item.selectedFormat.ext == "webm" {
                    return "bestvideo[ext=mp4][height<=\(heightLimit)]+bestaudio[ext=m4a]/bestvideo[ext=mp4][height<=\(heightLimit)]+bestaudio/bestvideo[height<=\(heightLimit)]+bestaudio/best[height<=\(heightLimit)]+bestaudio/best"
                }
                return "bestvideo[ext=mp4][height<=\(heightLimit)]+bestaudio[ext=m4a]/\(id)+bestaudio[ext=m4a]/\(id)+bestaudio/bestvideo[height<=\(heightLimit)]+bestaudio/best[height<=\(heightLimit)]+bestaudio/best"
            }
            if id.hasPrefix("best") {
                let bracket = id.firstIndex(of: "[") ?? id.endIndex
                let filter = id[bracket...]
                return "bestvideo\(filter)+bestaudio/\(id)"
            }
            return "\(id)/\(id)"
        }()
        var args: [String] = [
            "--newline",
            "--progress",
            "--no-warnings",
        ]
        args += Constants.youtubeExtractorArgs
        // 오디오만: m4a 원본을 그대로 받으므로 병합/리먹스 불필요 (webm 오디오 리먹스로
        // m4a가 깨지는 것 방지). 영상 모드에만 mp4 병합 적용.
        if !item.audioOnly {
            args += ["--merge-output-format", "mp4", "--remux-video", "mp4"]
        }
        args += [
            "-f", formatId,
            "--ignore-no-formats-error",
            "-o", constructOutputTemplate(item: item, outputDir: outputDir, filenameTemplate: filenameTemplate),
        ]

        if let rate = settings.limitRateArg {
            args += ["--limit-rate", rate]
        }

        if item.includeSubtitles {
            let subLangs = LanguageService.subtitleLanguages
            args += ["--write-subs", "--sub-langs", subLangs]
            #if DEBUG
            Task { @MainActor in DebugLogManager.shared?.append("[DownloadManager] --sub-langs: \(subLangs)") }
            #endif
        }

        if item.audioOnly {
            // formatId가 이미 bestaudio[ext=m4a] — 영상 없이 m4a 원본만. 별도 -x 변환 불필요.
        }

        if settings.sponsorBlock {
            args += ["--sponsorblock-remove", "all"]
        }

        if settings.embedMetadata {
            args += ["--ffmpeg-location", Constants.ffmpegDirectory, "--embed-metadata", "--embed-thumbnail"]
        }

        args.append(item.videoInfo.webpageURL)
        return args
    }

    private func constructOutputTemplate(item: DownloadItem, outputDir: String, filenameTemplate: String) -> String {
        let folder = Constants.sanitizeFolderName(item.videoInfo.channel)
        let channelDir = "\(outputDir)/\(folder)"
        try? FileManager.default.createDirectory(atPath: channelDir, withIntermediateDirectories: true)

        if item.isChannelDownload {
            return "\(channelDir)/\(String(format: "%03d", item.channelUploadIndex)) - %(title)s.%(id)s.%(ext)s"
        }
        let template = filenameTemplate

        var ytdlTemplate = template
            .replacingOccurrences(of: "{channel}", with: "%(channel)s")
            .replacingOccurrences(of: "{title}", with: "%(title)s")
            .replacingOccurrences(of: "{index}", with: String(format: "%03d", item.channelUploadIndex))
            .replacingOccurrences(of: "{date}", with: "%(upload_date)s")
            .replacingOccurrences(of: "{resolution}", with: "%(height)sp")
        ytdlTemplate = ytdlTemplate.replacingOccurrences(of: "{id}", with: "")
        ytdlTemplate = ytdlTemplate.trimmingCharacters(in: CharacterSet(charactersIn: ".- "))

        return "\(channelDir)/\(ytdlTemplate).%(id)s.%(ext)s"
    }

    static func cleanupPartialFiles(videoId: String, in outputDir: String) {
        guard let channels = try? FileManager.default.contentsOfDirectory(atPath: outputDir) else { return }
        for channel in channels {
            let dir = "\(outputDir)/\(channel)"
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for file in files where file.contains(videoId) {
                let ext = (file as NSString).pathExtension.lowercased()
                let isPartial = file.hasSuffix(".part")
                    || ["webp", "jpg", "png", "jpeg"].contains(ext)
                    || file.range(of: #"\.f\d+\."#, options: .regularExpression) != nil
                if isPartial {
                    try? FileManager.default.removeItem(atPath: "\(dir)/\(file)")
                }
            }
        }
    }

    /// 실미디어 파일인지 검증한다. (.part/.webp/.jpg/.png 등 임시·썸네일은 제외)
    static func isValidMediaFile(_ path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0
        else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        let name = (path as NSString).lastPathComponent
        if name.range(of: #"\.f\d+\."#, options: .regularExpression) != nil { return false }
        return DownloadItem.mediaFileExtensions.contains(ext)
    }

    private static func saveSubtitlesToDB(videoPath: String) {
        let dir = (videoPath as NSString).deletingLastPathComponent
        let baseName = ((videoPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let fm = FileManager.default

        // Extract YouTube videoId from filename (last dot-separated component)
        let nameParts = baseName.components(separatedBy: ".")
        guard let videoId = nameParts.last, videoId.count >= 10 else { return }

        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return }

        for file in files {
            guard file.hasPrefix(baseName),
                  (file.hasSuffix(".vtt") || file.hasSuffix(".srt")) else { continue }

            let path = (dir as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }

            let text: String
            let lang: String
            if file.hasSuffix(".vtt") {
                text = SummarizationService.parseVTT(content)
                lang = file.contains(".ko.") ? "ko" : "en"
            } else {
                text = SummarizationService.parseSRT(content)
                lang = file.contains(".ko.") ? "ko" : "en"
            }

            if !text.isEmpty {
                DatabaseManager.shared.updateTranscript(videoId: videoId, transcript: text, language: lang, source: "downloaded")
            }
            try? fm.removeItem(atPath: path)
        }
    }
}
