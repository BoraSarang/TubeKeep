import Foundation
import AppKit
import ComposableArchitecture
import os

final class DownloadManager {
    static let shared = DownloadManager()

    private let runner = ProcessRunner()
    private let activeLock = OSAllocatedUnfairLock(initialState: [UUID: Process]())
    private var pausedItems: Set<UUID> = []
    private var settings: Settings = Settings()

    private init() {}

    func updateSettings(_ newSettings: Settings) {
        settings = newSettings
    }

    func startDownload(
        item: DownloadItem,
        progressHandler: @escaping @Sendable (UUID, Double, String) -> Void,
        completionHandler: @escaping @Sendable (UUID, Bool, String?) -> Void
    ) {
        let outputDir = settings.outputDirectory

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
                var stderrBuf = Data()

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

                while process.isRunning {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    try Task.checkCancellation()
                }
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil

                // Read remaining stderr for error message
                let errRemaining = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                stderrBuf.append(errRemaining)
                let errMsg = String(data: stderrBuf, encoding: .utf8)

                if !Task.isCancelled {
                    if process.terminationStatus == 0 {
                        completionHandler(item.id, true, nil)
                        if self.settings.playSoundOnComplete {
                            _ = await MainActor.run {
                                NSSound(named: "Purr")?.play()
                            }
                        }
                    } else {
                        completionHandler(item.id, false, errMsg ?? "알 수 없는 오류")
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
            return item.selectedFormat.id
        }()
        var args: [String] = [
            "--newline",
            "--progress",
            "--no-warnings",
            "--extractor-args", "youtube:lang=ko",
            "-f", formatId,
            "--merge-output-format", "mp4",
            "--remux-video", "mp4",
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
        let template = {
            guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
                  let data = json.data(using: .utf8),
                  let s = try? JSONDecoder().decode(Settings.self, from: data)
            else { return Constants.defaultFilenameTemplate }
            return s.filenameTemplate
        }()

        let ytdlTemplate = template
            .replacingOccurrences(of: "{channel}", with: "%(channel)s")
            .replacingOccurrences(of: "{title}", with: "%(title)s")
            .replacingOccurrences(of: "{index}", with: String(format: "%03d", item.channelUploadIndex))
            .replacingOccurrences(of: "{date}", with: "%(upload_date)s")
            .replacingOccurrences(of: "{resolution}", with: "%(height)sp")
            .replacingOccurrences(of: "{id}", with: "%(id)s")

        return "\(channelDir)/\(ytdlTemplate).%(ext)s"
    }
}
