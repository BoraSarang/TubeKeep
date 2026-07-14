import Foundation

actor ChannelFetchService {
    private let runner = ProcessRunner()

    func fetchChannelInfo(from url: String) async throws -> SubscribedChannel {
        // Ensure @handle URLs end with /videos so yt-dlp treats it as a playlist (fast)
        // instead of the channel home page (slow/unreliable)
        let videosURL: String = {
            let base = url.hasSuffix("/") ? String(url.dropLast()) : url
            guard base.contains("/@") else { return url }
            let suffixes = ["/videos", "/shorts", "/streams"]
            guard !suffixes.contains(where: { base.hasSuffix($0) }) else { return url }
            return base + "/videos"
        }()

        let output = try await runner.runSync(
            executable: Constants.ytDlpPath,
            arguments: ["--dump-json", "--no-download", "--playlist-end", "1", "--extractor-args", "youtube:lang=ko", videosURL]
        )

        guard let firstLine = output.components(separatedBy: .newlines).first,
              !firstLine.isEmpty,
              let data = firstLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ProcessError.outputParsingFailed("채널 정보 JSON 파싱 실패")
        }

        let channelId = json["channel_id"] as? String ?? ""
        let name = json["channel"] as? String
            ?? json["uploader"] as? String
            ?? json["playlist_uploader"] as? String
            ?? "Unknown"
        let subscriberCount = json["channel_follower_count"] as? Int
        let handle = json["uploader_id"] as? String

        // Fetch avatar from channel page HTML asynchronously
        let avatarURL = await fetchAvatarURL(channelId: channelId)

        return SubscribedChannel(
            id: channelId,
            name: name,
            handle: handle,
            avatarURL: avatarURL,
            subscriberCount: subscriberCount,
            videoCount: 0
        )
    }

    private func fetchAvatarURL(channelId: String) async -> String {
        let urlString = "https://www.youtube.com/channel/\(channelId)"
        guard let url = URL(string: urlString) else { return "" }
        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return "" }
            // Extract avatar URL from ytInitialData JSON
            guard let match = html.range(of: #""avatar""#) else {
                // Fallback: direct regex for yt3 URL
                let pattern = #"https://yt3\.googleusercontent\.com/[^"\\'\s]+=s\d+-c-k-c0x00ffffff-no-rj"#
                if let urlMatch = html.range(of: pattern, options: .regularExpression) {
                    return String(html[urlMatch])
                }
                return ""
            }
            // Find the nearest thumbnail URL after "avatar"
            let afterAvatar = html[match.upperBound...]
            let urlPattern = #"https://yt3\.googleusercontent\.com/[^"\\'\s]+=s\d+-c-k-c0x00ffffff-no-rj"#
            if let urlMatch = afterAvatar.range(of: urlPattern, options: .regularExpression) {
                return String(afterAvatar[urlMatch])
            }
            return ""
        } catch {
            return ""
        }
    }

    func fetchAllVideos(channelId: String, handle: String? = nil) async throws -> (videos: [ChannelVideoItem], totalCount: Int) {
        // Use /videos tab URL when handle is available (excludes shorts automatically)
        // Fallback to UU playlist if no handle
        let url: String
        if let handle = handle {
            url = "https://www.youtube.com/\(handle)/videos"
        } else {
            let playlistId = uploadsPlaylistID(from: channelId)
            url = "https://www.youtube.com/playlist?list=\(playlistId)"
        }

        let output = try await runner.runSync(
            executable: Constants.ytDlpPath,
            arguments: [
                "--flat-playlist",
                "--dump-json",
                "--ignore-errors",
                "--extractor-args", "youtube:lang=ko",
                url,
            ]
        )

        var videos: [ChannelVideoItem] = []
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String,
                  let title = json["title"] as? String
            else { continue }

            let playlistIndex = json["playlist_index"] as? Int ?? 0
            let uploadDate = json["upload_date"] as? String
            let viewCount = json["view_count"] as? Int ?? 0
            let duration = json["duration"] as? Int ?? 0

            videos.append(ChannelVideoItem(
                id: id,
                title: title,
                uploadDate: uploadDate,
                thumbnailURL: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg",
                playlistIndex: playlistIndex,
                viewCount: viewCount,
                duration: duration
            ))
        }

        videos.sort { $0.playlistIndex < $1.playlistIndex }
        return (videos, videos.count)
    }

    private func uploadsPlaylistID(from channelId: String) -> String {
        if channelId.hasPrefix("UC") {
            return "UU" + channelId.dropFirst(2)
        }
        return "UU" + channelId
    }
}
