import Foundation

actor TrendingService {
    private let runner = ProcessRunner()
    private var cache: [TrendingCategory: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 30 * 60

    struct CacheEntry {
        let videos: [TrendingVideo]
        let timestamp: Date

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < TrendingService.cacheTTL
        }
    }

    func fetch(category: TrendingCategory, maxResults: Int = 20) async throws -> [TrendingVideo] {
        if let entry = cache[category], entry.isValid {
            return entry.videos
        }

        let query = category.searchQuery
        let searchURL = "ytsearch\(maxResults):\(query)"

        let args = [
            Constants.ytDlpPath,
            "--flat-playlist",
            "--dump-json",
            "--no-download",
            "--no-warnings",
            searchURL,
        ]

        let output = try await runner.runSync(executable: "env", arguments: args)

        var videos: [TrendingVideo] = []
        for line in output.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let video = parseTrendingItem(from: json) {
                videos.append(video)
            }
        }

        cache[category] = CacheEntry(videos: videos, timestamp: Date())
        return videos
    }

    func refresh(category: TrendingCategory, maxResults: Int = 20) async throws -> [TrendingVideo] {
        cache.removeValue(forKey: category)
        return try await fetch(category: category, maxResults: maxResults)
    }

    func search(query: String, maxResults: Int = 20) async throws -> [TrendingVideo] {
        let searchURL = "ytsearch\(maxResults):\(query)"
        let args = [
            Constants.ytDlpPath,
            "--flat-playlist",
            "--dump-json",
            "--no-download",
            "--no-warnings",
            searchURL,
        ]
        let output = try await runner.runSync(executable: "env", arguments: args)
        var videos: [TrendingVideo] = []
        for line in output.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let video = parseTrendingItem(from: json) {
                videos.append(video)
            }
        }
        return videos
    }

    func invalidateAllCache() {
        cache.removeAll()
    }

    private func parseTrendingItem(from json: [String: Any]) -> TrendingVideo? {
        guard let id = json["id"] as? String,
              let title = json["title"] as? String
        else { return nil }

        let channel = json["channel"] as? String ?? json["uploader"] as? String ?? ""
        let channelId = json["channel_id"] as? String ?? json["uploader_id"] as? String ?? ""
        let viewCount = json["view_count"] as? Int
        let duration = json["duration"] as? Int
        let uploadDate = json["upload_date"] as? String
        let thumbnailURL = (json["thumbnail"] as? String) ??
            (json["thumbnails"] as? [[String: Any]])?.first?["url"] as? String ?? ""
        let webpageURL = json["webpage_url"] as? String ?? "https://youtu.be/\(id)"

        return TrendingVideo(
            id: id,
            title: title,
            channel: channel,
            channelId: channelId,
            viewCount: viewCount,
            duration: duration,
            uploadDate: uploadDate,
            thumbnailURL: thumbnailURL,
            webpageURL: webpageURL
        )
    }
}
