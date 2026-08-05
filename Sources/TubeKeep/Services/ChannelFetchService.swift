import Foundation

actor ChannelFetchService {
    private let runner = ProcessRunner()

    func fetchChannelInfo(from url: String) async throws -> SubscribedChannel {
        // Use the original URL directly - yt-dlp handles @handle, /channel/, /c/ formats
        let channelInfo = try await fetchChannelMetadata(from: url)

        // Fetch avatar from channel page
        let avatarURL = await fetchAvatarURL(channelId: channelInfo.id)

        return SubscribedChannel(
            id: channelInfo.id,
            name: channelInfo.name,
            handle: channelInfo.handle,
            avatarURL: avatarURL,
            subscriberCount: channelInfo.subscriberCount,
            videoCount: channelInfo.videoCount
        )
    }

    private struct ChannelMetadata {
        let id: String
        let name: String
        let handle: String?
        let subscriberCount: Int?
        let videoCount: Int
    }

    private func fetchChannelMetadata(from url: String) async throws -> ChannelMetadata {
        // Step 1: Get channel ID using flat playlist (avoids member-only video issue)
        let flatOutput = try await runner.runSync(
            executable: Constants.ytDlpPath,
            arguments: [
                "--dump-json",
                "--no-download",
                "--extractor-args", Constants.youtubeExtractorArgs,
                "--flat-playlist",
                "--playlist-end", "1",
                "--ignore-errors",
                "--no-warnings",
                url
            ]
        )

        guard let firstLine = flatOutput.components(separatedBy: .newlines).first,
              !firstLine.isEmpty,
              let data = firstLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ProcessError.outputParsingFailed("채널 정보 JSON 파싱 실패")
        }

        let id = json["playlist_channel_id"] as? String ?? ""
        let name = json["playlist_uploader"] as? String
            ?? json["playlist_channel"] as? String
            ?? "Unknown"
        let handle = json["playlist_uploader_id"] as? String

        // Step 2: Try to get subscriber count and video count from UU playlist
        // The UU playlist avoids the member-only issue because its first video is always accessible
        var subscriberCount: Int?
        var videoCount = 0

        if !id.isEmpty {
            let playlistId = "UU" + (id.hasPrefix("UC") ? String(id.dropFirst(2)) : id)
            let playlistURL = "https://www.youtube.com/playlist?list=\(playlistId)"

            if let metaOutput = try? await runner.runSync(
                executable: Constants.ytDlpPath,
                arguments: [
                    "--dump-json",
                    "--no-download",
                    "--extractor-args", Constants.youtubeExtractorArgs,
                    "--playlist-end", "1",
                    "--ignore-errors",
                    "--no-warnings",
                    playlistURL
                ]
            ) {
                if let metaLine = metaOutput.components(separatedBy: .newlines).first,
                   !metaLine.isEmpty,
                   let metaData = metaLine.data(using: .utf8),
                   let metaJson = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
                    subscriberCount = metaJson["channel_follower_count"] as? Int
                    videoCount = metaJson["playlist_count"] as? Int ?? 0
                }
            }
        }

        return ChannelMetadata(id: id, name: name, handle: handle, subscriberCount: subscriberCount, videoCount: videoCount)
    }

    func fetchAllVideos(
        channelId: String,
        handle: String? = nil,
        progressHandler: (@Sendable (Int) -> Void)? = nil
    ) async throws -> (videos: [ChannelVideoItem], totalCount: Int) {
        // Use /videos page to exclude Shorts; fall back to UU playlist for member-only exclusion
        let url: String
        if let handle = handle, !handle.isEmpty {
            url = "https://www.youtube.com/\(handle)/videos"
        } else {
            let playlistId = "UU" + (channelId.hasPrefix("UC") ? String(channelId.dropFirst(2)) : channelId)
            url = "https://www.youtube.com/playlist?list=\(playlistId)"
        }

        let stream = await runner.runStreamingStdout(
            executable: Constants.ytDlpPath,
            arguments: [
                "--flat-playlist",
                "--dump-json",
                "--extractor-args", Constants.youtubeExtractorArgs,
                "--ignore-errors",
                "--no-warnings",
                url,
            ],
            environment: ["PYTHONUNBUFFERED": "1"]
        )

        var videos: [ChannelVideoItem] = []
        var lineBuffer = ""
        for try await chunk in stream {
            lineBuffer += chunk
            while let newlineRange = lineBuffer.range(of: "\n") {
                let line = String(lineBuffer[..<newlineRange.lowerBound])
                lineBuffer.removeSubrange(lineBuffer.startIndex..<newlineRange.upperBound)
                if let item = parseVideoLine(line) {
                    videos.append(item)
                    progressHandler?(videos.count)
                }
            }
        }
        if !lineBuffer.isEmpty, let item = parseVideoLine(lineBuffer) {
            videos.append(item)
            progressHandler?(videos.count)
        }

        videos.sort { $0.playlistIndex < $1.playlistIndex }
        return (videos, videos.count)
    }

    func estimateLoadDuration(
        channelId: String,
        handle: String? = nil,
        totalCount: Int
    ) async throws -> TimeInterval {
        guard totalCount > 0 else { return 0 }
        let url: String
        if let handle = handle, !handle.isEmpty {
            url = "https://www.youtube.com/\(handle)/videos"
        } else {
            let playlistId = "UU" + (channelId.hasPrefix("UC") ? String(channelId.dropFirst(2)) : channelId)
            url = "https://www.youtube.com/playlist?list=\(playlistId)"
        }

        let probeItems = 30
        let start = Date()
        let output = try await runner.runSync(
            executable: Constants.ytDlpPath,
            arguments: [
                "--flat-playlist",
                "--dump-json",
                "--extractor-args", Constants.youtubeExtractorArgs,
                "--ignore-errors",
                "--no-warnings",
                "--playlist-items", "1-\(probeItems)",
                url,
            ]
        )
        let probeElapsed = Date().timeIntervalSince(start)
        let itemCount = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .compactMap { parseVideoLine($0) }
            .count

        guard itemCount > 0, probeElapsed > 0.05 else { return 0 }
        let rate = Double(itemCount) / probeElapsed
        return Double(totalCount) / rate
    }

    private func parseVideoLine(_ line: String) -> ChannelVideoItem? {
        guard !line.isEmpty,
              let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let title = json["title"] as? String
        else { return nil }

        // Exclude member-only / subscriber-only content
        if let availability = json["availability"] as? String,
           availability == "subscriber_only"
        { return nil }

        let playlistIndex = json["playlist_index"] as? Int ?? 0
        let uploadDate = json["upload_date"] as? String
        let viewCount = json["view_count"] as? Int ?? 0
        let duration = (json["duration"] as? Int) ?? (json["duration"] as? Double).map(Int.init) ?? 0

        return ChannelVideoItem(
            id: id,
            title: title,
            uploadDate: uploadDate,
            thumbnailURL: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg",
            playlistIndex: playlistIndex,
            viewCount: viewCount,
            duration: duration
        )
    }

    private func fetchAvatarURL(channelId: String) async -> String {
        let urlString = "https://www.youtube.com/channel/\(channelId)"
        guard let url = URL(string: urlString) else { return "" }
        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return "" }
            guard let match = html.range(of: #""avatar""#) else {
                let pattern = #"https://yt3\.googleusercontent\.com/[^"\\'\s]+=s\d+-c-k-c0x00ffffff-no-rj"#
                if let urlMatch = html.range(of: pattern, options: .regularExpression) {
                    return String(html[urlMatch])
                }
                return ""
            }
            let afterAvatar = html[match.upperBound...]
            let urlPattern = #"https://yt3\.googleusercontent\.com/[^"\\'\s]+=s\d+-c-k-c0x00ffffff-no-rj"#
            if let urlMatch = afterAvatar.range(of: urlPattern, options: .regularExpression) {
                return String(html[urlMatch])
            }
            return ""
        } catch {
            return ""
        }
    }
}