import Foundation

actor YouTubeDLService {
    private let runner = ProcessRunner()

    enum YTDLPError: LocalizedError {
        case notInstalled
        case infoFetchFailed(String)
        case downloadFailed(String)
        case playlistFetchFailed(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "yt-dlp가 설치되지 않았습니다.\n터미널에 'brew install yt-dlp'를 입력해 주세요."
            case let .infoFetchFailed(msg):
                return "정보 조회 실패: \(ErrorMessageMapper.map(msg))"
            case let .downloadFailed(msg):
                return "다운로드 실패: \(ErrorMessageMapper.map(msg))"
            case let .playlistFetchFailed(msg):
                return "재생목록 조회 실패: \(ErrorMessageMapper.map(msg))"
            }
        }
    }

    static func checkInstallationStatic() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [Constants.ytDlpPath, "--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func checkInstallation() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [Constants.ytDlpPath, "--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func fetchVideoInfo(
        url: String,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> (VideoInfo, [Format]) {
        let cookies = LanguageService.cookiesArgs
        do {
            return try await _runInfoFetch(url: url, cookies: cookies, progressHandler: progressHandler)
        } catch let error as YTDLPError {
            if case let .infoFetchFailed(stderr) = error, !cookies.isEmpty {
                let lower = stderr.lowercased()
                if lower.contains("cookie") || lower.contains("could not find") || lower.contains("keyring") || lower.contains("browser") {
                    #if DEBUG
                    Task { @MainActor in
                        DebugLogManager.shared?.append("[YouTubeDL] 쿠키 추출 실패, 쿠키 없이 재시도")
                    }
                    #endif
                    return try await _runInfoFetch(url: url, cookies: [], progressHandler: progressHandler)
                }
            }
            throw error
        }
    }

    private func _runInfoFetch(
        url: String,
        cookies: [String],
        progressHandler: (@Sendable (String) -> Void)?
    ) async throws -> (VideoInfo, [Format]) {
        guard checkInstallation() else {
            throw YTDLPError.notInstalled
        }

        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        let stderrURL = tmp.appendingPathComponent("ytdlp_stderr_\(UUID().uuidString.prefix(8)).log")
        let stdoutURL = tmp.appendingPathComponent("ytdlp_stdout_\(UUID().uuidString.prefix(8)).log")
        if fm.fileExists(atPath: stderrURL.path) { try? fm.removeItem(at: stderrURL) }
        if fm.fileExists(atPath: stdoutURL.path) { try? fm.removeItem(at: stdoutURL) }
        fm.createFile(atPath: stderrURL.path, contents: nil)
        fm.createFile(atPath: stdoutURL.path, contents: nil)
        let stderrFile = try FileHandle(forWritingTo: stderrURL)
        let stdoutFile = try FileHandle(forWritingTo: stdoutURL)

        let process = Process()

        defer {
            if process.isRunning { process.terminate() }
            try? fm.removeItem(at: stderrURL)
            try? fm.removeItem(at: stdoutURL)
        }
        ProcessRegistry.register(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = [Constants.ytDlpPath, "--verbose", "--dump-json", "--no-download", "--extractor-args", Constants.youtubeExtractorArgs, url]
        if !cookies.isEmpty { args += cookies }
        #if DEBUG
        if !cookies.isEmpty { Task { @MainActor in DebugLogManager.shared?.append("[YouTubeDL] 쿠키 적용: \(cookies.joined(separator: " "))") } }
        #endif
        process.arguments = args

        process.standardOutput = stdoutFile
        process.standardError = stderrFile

        try process.run()
        stderrFile.closeFile()
        stdoutFile.closeFile()

        var stderrOutput = ""
        var lastStderrSize: UInt64 = 0
        let deadline = ContinuousClock.now + .seconds(120)

        while process.isRunning {
            if ContinuousClock.now >= deadline {
                process.terminate()
                throw YTDLPError.infoFetchFailed("정보 조회 시간 초과 (120초)")
            }
            try await Task.sleep(nanoseconds: 100_000_000)
            try Task.checkCancellation()

            let attrs = try? fm.attributesOfItem(atPath: stderrURL.path)
            let currentSize = (attrs?[.size] as? UInt64) ?? 0
            if currentSize > lastStderrSize, let data = try? Data(contentsOf: stderrURL) {
                let newBytes = data[Int(lastStderrSize)...]
                if let output = String(data: newBytes, encoding: .utf8) {
                    stderrOutput += output
                    for line in output.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            progressHandler?(trimmed + "\n")
                        }
                    }
                }
                lastStderrSize = currentSize
            }
        }

        if let data = try? Data(contentsOf: stderrURL), data.count > Int(lastStderrSize) {
            let newBytes = data[Int(lastStderrSize)...]
            if let output = String(data: newBytes, encoding: .utf8) {
                stderrOutput += output
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        progressHandler?(trimmed + "\n")
                    }
                }
            }
        }

        let stdoutData = (try? Data(contentsOf: stdoutURL)) ?? Data()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            #if DEBUG
            let trimmed = stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Task { @MainActor in
                    DebugLogManager.shared?.append("[yt-dlp 오류] \(trimmed)")
                }
            }
            #endif
            throw YTDLPError.infoFetchFailed(stderrOutput)
        }

        guard let data = stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw YTDLPError.infoFetchFailed("JSON 파싱 실패")
        }

        let videoInfo = try parseVideoInfo(from: json, originalURL: url)
        let formats = try parseFormats(from: json)

        if formats.isEmpty {
            throw YTDLPError.infoFetchFailed("다운로드 가능한 포맷이 없습니다")
        }

        return (videoInfo, formats)
    }

    static func streamingFormat(for resolution: Int) -> String {
        let steps: [Int]
        if resolution >= 2160 { steps = [2160, 1080, 720] }
        else if resolution >= 1440 { steps = [1440, 1080, 720] }
        else if resolution >= 1080 { steps = [1080, 720, 480] }
        else if resolution >= 720 { steps = [720, 480] }
        else if resolution >= 480 { steps = [480, 360] }
        else if resolution >= 360 { steps = [360, 240, 144] }
        else if resolution >= 240 { steps = [240, 144] }
        else { steps = [144] }
        let parts = steps.map { "best[height<=\($0)]" }
        return (parts + ["best"]).joined(separator: "/")
    }

    func fetchStreamingURL(url: String, resolution: Int = 0) async throws -> URL {
        guard checkInstallation() else {
            throw YTDLPError.notInstalled
        }

        let format = Self.streamingFormat(for: resolution)
        var args = [
            Constants.ytDlpPath,
            "-f", format,
            "--get-url",
            "--no-warnings",
        ]
        let cookies = LanguageService.cookiesArgs
        if !cookies.isEmpty { args += cookies }
        #if DEBUG
        if !cookies.isEmpty { Task { @MainActor in DebugLogManager.shared?.append("[YouTubeDL] 스트리밍 쿠키 적용: \(cookies.joined(separator: " "))") } }
        #endif
        args.append(url)
        let output = try await runner.runSync(executable: "env", arguments: args)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let streamURL = URL(string: trimmed) else {
            throw YTDLPError.infoFetchFailed("스트리밍 URL을 가져올 수 없습니다")
        }
        return streamURL
    }

    func fetchPlaylist(url: String) async throws -> [VideoInfo] {
        guard checkInstallation() else {
            throw YTDLPError.notInstalled
        }

        let args = [
            Constants.ytDlpPath,
            "--flat-playlist",
            "--dump-json",
            "--no-download",
            "--no-warnings",
            url,
        ]

        let output = try await runner.runSync(executable: "env", arguments: args)

        var videos: [VideoInfo] = []
        for line in output.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
            guard let data = line.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let video = try? parsePlaylistItem(from: json) {
                videos.append(video)
            }
        }

        return videos
    }

    func download(
        item: DownloadItem,
        outputDir: String,
        limitRate: String? = nil,
        sponsorBlock: Bool = true,
        embedMetadata: Bool = true,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let args = buildDownloadArgs(
            item: item,
            outputDir: outputDir,
            limitRate: limitRate,
            sponsorBlock: sponsorBlock,
            embedMetadata: embedMetadata
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = await self.runner.run(
                        executable: Constants.ytDlpPath,
                        arguments: args,
                        progressHandler: progressHandler
                    )

                    for try await output in stream {
                        continuation.yield(output)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildDownloadArgs(
        item: DownloadItem,
        outputDir: String,
        limitRate: String?,
        sponsorBlock: Bool = true,
        embedMetadata: Bool = true
    ) -> [String] {
        let formatId: String = {
            let id = item.selectedFormat.id
            if item.selectedFormat.isVideoOnly {
                let height = item.selectedFormat.height
                let fallback = "\(id)+bestaudio/best[height<=\(height)]"
                return "\(id)+bestaudio/\(fallback)"
            }
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
            "--print-to-file", "after_move:filepath", "/dev/null",
            "--extractor-args", Constants.youtubeExtractorArgs,
            "-f", formatId,
            "--merge-output-format", "mp4",
            "--remux-video", "mp4",
            "-o", constructOutputTemplate(item: item, outputDir: outputDir),
        ]

        if let rate = limitRate {
            args += ["--limit-rate", rate]
        }

        if item.includeSubtitles {
            let subLangs = LanguageService.subtitleLanguages
            args += ["--write-subs", "--write-auto-subs", "--sub-langs", subLangs]
            #if DEBUG
            Task { @MainActor in DebugLogManager.shared?.append("[YouTubeDLService] --sub-langs: \(subLangs)") }
            #endif
        }

        if item.audioOnly {
            args += ["-x", "--audio-format", "aac", "--audio-quality", "0"]
        }

        if sponsorBlock {
            args += ["--sponsorblock-remove", "all"]
        }

        if embedMetadata {
            args += ["--ffmpeg-location", Constants.ffmpegDirectory, "--embed-metadata", "--embed-thumbnail"]
        }

        let cookies = LanguageService.cookiesArgs
        if !cookies.isEmpty { args += cookies }
        #if DEBUG
        if !cookies.isEmpty { Task { @MainActor in DebugLogManager.shared?.append("[YouTubeDL] 다운로드 쿠키 적용: \(cookies.joined(separator: " "))") } }
        #endif
        args.append(item.videoInfo.webpageURL)
        return args
    }

    private func constructOutputTemplate(item: DownloadItem, outputDir: String) -> String {
        if item.isChannelDownload {
            let folder = Constants.sanitizeFolderName(item.videoInfo.channel)
            let channelDir = "\(Constants.channelStorageDirectory)/\(folder)"
            try? FileManager.default.createDirectory(atPath: channelDir, withIntermediateDirectories: true)
            return "\(channelDir)/\(String(format: "%03d", item.channelUploadIndex)) - %(title)s.%(id)s.%(ext)s"
        }
        let settings = Settings.loadSettings()
        var template = settings.filenameTemplate

        if item.channelUploadIndex == 0,
            settings.skipIndexOnFailure == true {
            template = DownloadItem.removeIndexPlaceholder(from: template)
        }

        let ytdlTemplate = template
            .replacingOccurrences(of: "{channel}", with: "%(channel)s")
            .replacingOccurrences(of: "{title}", with: "%(title)s")
            .replacingOccurrences(of: "{index}", with: String(format: "%03d", item.channelUploadIndex))
            .replacingOccurrences(of: "{date}", with: "%(upload_date)s")
            .replacingOccurrences(of: "{resolution}", with: "%(height)sp")
            .replacingOccurrences(of: "{id}", with: "%(id)s")

        return "\(outputDir)/\(ytdlTemplate).%(ext)s"
    }

    private func parseVideoInfo(from json: [String: Any], originalURL: String = "") throws -> VideoInfo {
        guard let id = json["id"] as? String,
              let title = json["title"] as? String,
              let channel = json["channel"] as? String ?? json["uploader"] as? String,
              let channelId = json["channel_id"] as? String,
              let duration = json["duration"] as? TimeInterval ?? json["duration_string"].flatMap({ Double("\($0)") })
        else {
            throw YTDLPError.infoFetchFailed("필수 정보 누락")
        }

        let uploadDate = json["upload_date"] as? String ?? ""
        let thumbnailURL = (json["thumbnail"] as? String) ??
            (json["thumbnails"] as? [[String: Any]])?.last?["url"] as? String ?? ""
        let webpageURL = json["webpage_url"] as? String ?? originalURL
        let isPlaylist = json["playlist_id"] as? String != nil &&
            json["playlist_index"] != nil
        let playlistTitle = json["playlist_title"] as? String
        let playlistCount = json["playlist_count"] as? Int

        return VideoInfo(
            id: id,
            title: title,
            channel: channel,
            channelId: channelId,
            duration: duration,
            uploadDate: uploadDate,
            thumbnailURL: thumbnailURL,
            webpageURL: webpageURL,
            isPlaylist: isPlaylist,
            playlistTitle: playlistTitle,
            playlistCount: playlistCount
        )
    }

    private func parseFormats(from json: [String: Any]) throws -> [Format] {
        guard let formatsJSON = json["formats"] as? [[String: Any]] else {
            throw YTDLPError.infoFetchFailed("포맷 정보 없음")
        }

        var formatMap: [Int: Format] = [:]

        for fmt in formatsJSON {
            guard let formatId = fmt["format_id"] as? String,
                  let ext = fmt["ext"] as? String
            else { continue }

            let height = fmt["height"] as? Int ?? 0
            let codec = (fmt["vcodec"] as? String ?? "unknown")
                .replacingOccurrences(of: "av01", with: "AV1")
                .replacingOccurrences(of: "vp9", with: "VP9")
                .replacingOccurrences(of: "vp9.2", with: "VP9")
                .replacingOccurrences(of: "avc1", with: "h264")
                .replacingOccurrences(of: "h265", with: "HEVC")
                .replacingOccurrences(of: "hevc", with: "HEVC")
            let filesize = fmt["filesize"] as? Int64 ?? fmt["filesize_approx"] as? Int64
            let fps = fmt["fps"] as? Int
            let isVideoOnly = (fmt["vcodec"] as? String ?? "") != "none" &&
                (fmt["acodec"] as? String ?? "") == "none"
            let isAudioOnly = (fmt["vcodec"] as? String ?? "") == "none"

            guard height > 0 else { continue }

            if let existing = formatMap[height] {
                if !existing.isVideoOnly { continue }
                if !isVideoOnly {
                    formatMap[height] = Format(
                        id: formatId,
                        label: "\(height)p",
                        height: height,
                        ext: ext == "webm" ? "webm" : "mp4",
                        codec: codec,
                        filesize: filesize,
                        fps: fps,
                        isVideoOnly: isVideoOnly,
                        isAudioOnly: isAudioOnly
                    )
                    continue
                }
                let existingScore = existing.filesize ?? 0
                let newScore = filesize ?? 0
                if newScore > existingScore {
                    formatMap[height] = Format(
                        id: formatId,
                        label: "\(height)p",
                        height: height,
                        ext: ext == "webm" ? "webm" : "mp4",
                        codec: codec,
                        filesize: filesize,
                        fps: fps,
                        isVideoOnly: isVideoOnly,
                        isAudioOnly: isAudioOnly
                    )
                }
            } else {
                formatMap[height] = Format(
                    id: formatId,
                    label: "\(height)p",
                    height: height,
                    ext: ext == "webm" ? "webm" : "mp4",
                    codec: codec,
                    filesize: filesize,
                    fps: fps,
                    isVideoOnly: isVideoOnly,
                    isAudioOnly: isAudioOnly
                )
            }
        }

        return formatMap.values
            .filter { $0.filesize != nil || !formatMap.values.contains(where: { $0.height == $0.height && $0.filesize != nil }) }
            .sorted { $0.height > $1.height }
    }

    private func parsePlaylistItem(from json: [String: Any]) throws -> VideoInfo {
        guard let id = json["id"] as? String,
              let title = json["title"] as? String
        else {
            throw YTDLPError.playlistFetchFailed("재생목록 항목 파싱 실패")
        }

        let channel = json["channel"] as? String ??
            json["uploader"] as? String ?? ""
        let channelId = json["channel_id"] as? String ?? json["uploader_id"] as? String ?? ""
        let duration = json["duration"] as? TimeInterval ?? 0
        let uploadDate = json["upload_date"] as? String ?? ""
        let thumbnailURL = (json["thumbnail"] as? String) ??
            (json["thumbnails"] as? [[String: Any]])?.first?["url"] as? String ?? ""
        let webpageURL = json["webpage_url"] as? String ?? ""

        return VideoInfo(
            id: id,
            title: title,
            channel: channel,
            channelId: channelId,
            duration: duration,
            uploadDate: uploadDate,
            thumbnailURL: thumbnailURL,
            webpageURL: webpageURL,
            isPlaylist: false,
            playlistTitle: nil,
            playlistCount: nil
        )
    }
}
