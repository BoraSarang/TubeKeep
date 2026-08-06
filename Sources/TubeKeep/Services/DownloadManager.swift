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
        let s = stateLock.withLock { $0.settings }
        let outputDir = s.storageDirectory
        let tmpl = stateLock.withLock { $0.filenameTemplate }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                try Task.checkCancellation()
            } catch { return }
            if stateLock.withLock({ $0.canceledItems.contains(item.id) }) { return }

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
                    guard !data.isEmpty else { return }
                    guard let output = String(data: data, encoding: .utf8) else { return }

                    for line in output.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { continue }
                        let parts = trimmed.components(separatedBy: "|")
                        guard parts.count >= 2 else { continue }

                        let pctRaw = parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                        let spdStr = parts[1].trimmingCharacters(in: .whitespaces)

                        guard let pct = Double(pctRaw) else { continue }
                        if pct != box.lastPercent || !spdStr.isEmpty {
                            box.lastPercent = pct
                            box.lastSpeed = spdStr
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
                    try await Task.sleep(nanoseconds: 300_000_000)
                    try Task.checkCancellation()
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

                if !Task.isCancelled && !suppressed {
                    let actualPath: String? = {
                        let fm = FileManager.default
                        // 1) Try after_move:filepath first
                        let afterMovePath: String? = {
                            guard let data = try? Data(contentsOf: URL(fileURLWithPath: outputPathFile)),
                                  let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                                  !path.isEmpty
                            else { return nil }
                            try? fm.removeItem(atPath: outputPathFile)
                            return path
                        }()
                        // 2) Validate: file must exist
                        if let path = afterMovePath, fm.fileExists(atPath: path) {
                            return path
                        }
                        // 3) Fallback: scan output directory for videoId
                        let folder = Constants.sanitizeFolderName(item.videoInfo.channel)
                        let channelDir = "\(outputDir)/\(folder)"
                        let videoId = item.videoInfo.id
                        guard let files = try? fm.contentsOfDirectory(atPath: channelDir) else { return nil }
                        for file in files where file.contains(videoId) {
                            return "\(channelDir)/\(file)"
                        }
                        return nil
                    }()

                    if process.terminationStatus == 0 || (actualPath.map { FileManager.default.fileExists(atPath: $0) } ?? false) {
                        if item.includeSubtitles, let path = actualPath {
                            Self.saveSubtitlesToDB(videoPath: path)
                        }
                        completionHandler(item.id, true, actualPath, nil)
                        if s.playSoundOnComplete {
                            _ = await MainActor.run {
                                NSSound(named: "Purr")?.play()
                            }
                        }
                    } else {
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
        if let p = process, p.isRunning { p.terminate() }
    }

    @discardableResult
    func cancelAll() -> Int {
        let processes = activeLock.withLock {
            let values = Array($0.values)
            $0.removeAll()
            return values
        }
        for p in processes where p.isRunning {
            p.terminate()
        }
        stateLock.withLock { $0.pausedItems.removeAll() }
        return processes.count
    }

    var activeCount: Int {
        activeLock.withLock { $0.count }
    }

    func isPaused(_ itemId: UUID) -> Bool { stateLock.withLock { $0.pausedItems.contains(itemId) } }

    private func buildDownloadArgs(item: DownloadItem, outputDir: String, settings: Settings, filenameTemplate: String) -> [String] {
        let formatId: String = {
            if item.selectedFormat.isVideoOnly {
                let height = item.selectedFormat.height
                let fallback = "\(item.selectedFormat.id)+bestaudio/best[height<=\(height)]"
                return "\(item.selectedFormat.id)+bestaudio/\(fallback)"
            }
            let id = item.selectedFormat.id
            if id.hasPrefix("best") && !id.contains("/") && !id.contains("+") {
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
            "--extractor-args", Constants.youtubeExtractorArgs,
            "-f", formatId,
            "--merge-output-format", "mp4",
            "--remux-video", "mp4",
            "--ignore-no-formats-error",
            "-o", constructOutputTemplate(item: item, outputDir: outputDir, filenameTemplate: filenameTemplate),
        ]

        if let rate = settings.limitRateArg {
            args += ["--limit-rate", rate]
        }

        if item.includeSubtitles {
            let subLangs = LanguageService.subtitleLanguages
            args += ["--write-subs", "--write-auto-subs", "--sub-langs", subLangs]
            #if DEBUG
            Task { @MainActor in DebugLogManager.shared?.append("[DownloadManager] --sub-langs: \(subLangs)") }
            #endif
        }

        if item.audioOnly {
            args += ["-x", "--audio-format", "aac", "--audio-quality", "0"]
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
                DatabaseManager.shared.updateTranscript(videoId: videoId, transcript: text, language: lang)
            }
            try? fm.removeItem(atPath: path)
        }
    }
}
