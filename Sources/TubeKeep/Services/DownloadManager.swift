import Foundation
import AppKit
import ComposableArchitecture
import os

final class DownloadManager: @unchecked Sendable {
    static let shared = DownloadManager()

    private let runner = ProcessRunner()
    private let activeLock = OSAllocatedUnfairLock(initialState: [UUID: Process]())
    private var pausedItems: Set<UUID> = []
    private var settings: Settings = Settings()
    private var storageDirectory: String = Constants.defaultStorageDirectory
    private var filenameTemplate: String = Constants.defaultFilenameTemplate

    private init() {}

    func updateSettings(_ newSettings: Settings) {
        settings = newSettings
        storageDirectory = newSettings.storageDirectory
        filenameTemplate = newSettings.filenameTemplate
    }

    func startDownload(
        item: DownloadItem,
        progressHandler: @escaping @Sendable (UUID, Double, String) -> Void,
        completionHandler: @escaping @Sendable (UUID, Bool, String?) -> Void,
        logHandler: (@Sendable (UUID, String) -> Void)? = nil
    ) {
        let outputDir = settings.storageDirectory

        Task { [weak self] in
            guard let self = self else { return }

            var args = buildDownloadArgs(item: item, outputDir: outputDir)
            args += ["--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s"]

            let process = Process()
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
                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                        buf.data.append(data)
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

                // Read remaining stderr for error message
                let errRemaining = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                buf.data.append(errRemaining)
                let errMsg = String(data: buf.data, encoding: .utf8)

                if !Task.isCancelled {
                    if process.terminationStatus == 0 {
                        completionHandler(item.id, true, nil)
                        if self.settings.playSoundOnComplete {
                            _ = await MainActor.run {
                                NSSound(named: "Purr")?.play()
                            }
                        }
                    } else {
                        completionHandler(item.id, false, ErrorMessageMapper.map(errMsg))
                    }
                }
            } catch {
                if !Task.isCancelled {
                    completionHandler(item.id, false, error.localizedDescription)
                }
            }
        }
    }

    func pauseDownload(itemId: UUID) {
        let process = activeLock.withLock { $0[itemId] }
        guard let p = process, p.isRunning else { return }
        p.interrupt()
        pausedItems.insert(itemId)
    }

    func resumeDownload(item: DownloadItem,
                        progressHandler: @escaping @Sendable (UUID, Double, String) -> Void,
                        completionHandler: @escaping @Sendable (UUID, Bool, String?) -> Void) {
        pausedItems.remove(item.id)
        startDownload(item: item, progressHandler: progressHandler, completionHandler: completionHandler)
    }

    func cancelDownload(itemId: UUID) {
        let process = activeLock.withLock { $0.removeValue(forKey: itemId) }
        if let p = process, p.isRunning { p.terminate() }
        pausedItems.remove(itemId)
    }

    func cancelAll() {
        let processes = activeLock.withLock {
            let values = Array($0.values)
            $0.removeAll()
            return values
        }
        for p in processes where p.isRunning {
            p.terminate()
        }
        pausedItems.removeAll()
    }

    var activeCount: Int {
        activeLock.withLock { $0.count }
    }

    func isPaused(_ itemId: UUID) -> Bool { pausedItems.contains(itemId) }

    private func buildDownloadArgs(item: DownloadItem, outputDir: String) -> [String] {
        let formatId: String = {
            if item.selectedFormat.isVideoOnly {
                let height = item.selectedFormat.height
                return "\(item.selectedFormat.id)+bestaudio[ext=m4a]/\(item.selectedFormat.id)+bestaudio/best[height<=\(height)]"
            }
            let id = item.selectedFormat.id
            if id.hasPrefix("best") {
                let bracket = id.firstIndex(of: "[") ?? id.endIndex
                let filter = id[bracket...]
                return "bestvideo\(filter)+bestaudio/\(id)"
            }
            return id
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
            "-o", constructOutputTemplate(item: item, outputDir: outputDir),
        ]

        if let rate = settings.limitRateArg {
            args += ["--limit-rate", rate]
        }

        if item.includeSubtitles {
            args += ["--write-subs", "--write-auto-subs", "--sub-langs", "en,ko"]
        }

        if item.audioOnly {
            args += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        }

        if settings.sponsorBlock {
            args += ["--sponsorblock-remove", "all"]
        }

        if settings.embedMetadata {
            args += ["--embed-metadata", "--embed-thumbnail"]
        }

        args.append(item.videoInfo.webpageURL)
        return args
    }

    private func constructOutputTemplate(item: DownloadItem, outputDir: String) -> String {
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
}
