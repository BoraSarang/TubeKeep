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

    func fetchAllVideos(channelId: String, handle: String? = nil) async throws -> (videos: [ChannelVideoItem], totalCount: Int) {
        // Use /videos page to exclude Shorts; fall back to UU playlist for member-only exclusion
        let url: String
        if let handle = handle, !handle.isEmpty {
            url = "https://www.youtube.com/\(handle)/videos"
        } else {
            let playlistId = "UU" + (channelId.hasPrefix("UC") ? String(channelId.dropFirst(2)) : channelId)
            url = "https://www.youtube.com/playlist?list=\(playlistId)"
        }

        let output = try await runner.runSync(
            executable: Constants.ytDlpPath,
            arguments: [
                "--flat-playlist",
                "--dump-json",
                "--extractor-args", Constants.youtubeExtractorArgs,
                "--ignore-errors",
                "--no-warnings",
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

            // Exclude member-only / subscriber-only content
            if let availability = json["availability"] as? String,
               availability == "subscriber_only"
            { continue }

            let playlistIndex = json["playlist_index"] as? Int ?? 0
            let uploadDate = json["upload_date"] as? String
            let viewCount = json["view_count"] as? Int ?? 0
            let duration = (json["duration"] as? Int) ?? (json["duration"] as? Double).map(Int.init) ?? 0

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