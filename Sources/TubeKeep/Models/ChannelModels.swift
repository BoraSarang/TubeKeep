import Foundation

struct ChannelVideoItem: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let uploadDate: String?
    let thumbnailURL: String
    let playlistIndex: Int
    let viewCount: Int
    let duration: Int
}

enum ChannelSortOrder: String, Equatable, CaseIterable {
    case dateDesc = "최신순"
    case dateAsc = "오래된순"
}

extension ChannelVideoItem {
    var displayDate: String {
        guard let uploadDate = uploadDate else { return "날짜 없음" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        guard let date = formatter.date(from: uploadDate) else { return uploadDate }
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    var displayViewCount: String {
        if viewCount >= 10000 {
            return String(format: "%.1f만", Double(viewCount) / 10000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: viewCount)) ?? "\(viewCount)"
    }

    var displayDuration: String {
        if duration >= 3600 {
            let h = duration / 3600
            let m = (duration % 3600) / 60
            let s = duration % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        let m = duration / 60
        let s = duration % 60
        return String(format: "%d:%02d", m, s)
    }

    var thumbnailURLStandard: String {
        "https://i.ytimg.com/vi/\(id)/mqdefault.jpg"
    }
}

struct ChannelDownloadCache {
    private static let cacheKey = "channelDownloads"
    private static let fetchTimestampsKey = "channelFetchTimestamps"
    private static let videosDataKey = "channelVideosData"
    private static let newVideosKey = "channelsNewVideos"
    private static let seenVideosKey = "channelsSeenVideoIds"

    private static var videoCache: [String: [ChannelVideoItem]] = [:]

    static func cachedVideos(channelId: String) -> [ChannelVideoItem]? {
        if let cached = videoCache[channelId] { return cached }
        // Load from persistent cache on cache miss (app restart)
        guard let data = UserDefaults.standard.data(forKey: videosDataKey),
              let dict = try? JSONDecoder().decode([String: [ChannelVideoItem]].self, from: data),
              let videos = dict[channelId]
        else { return nil }
        videoCache[channelId] = videos
        return videos
    }

    static func setCachedVideos(channelId: String, videos: [ChannelVideoItem]) {
        videoCache[channelId] = videos
        // Persist to UserDefaults
        var dict: [String: [ChannelVideoItem]] = [:]
        if let data = UserDefaults.standard.data(forKey: videosDataKey),
           let d = try? JSONDecoder().decode([String: [ChannelVideoItem]].self, from: data) {
            dict = d
        }
        dict[channelId] = videos
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: videosDataKey)
    }

    static func clearVideoCache(channelId: String) {
        videoCache.removeValue(forKey: channelId)
        guard let data = UserDefaults.standard.data(forKey: videosDataKey),
              var dict = try? JSONDecoder().decode([String: [ChannelVideoItem]].self, from: data)
        else { return }
        dict.removeValue(forKey: channelId)
        guard let newData = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(newData, forKey: videosDataKey)
    }

    static func loadDownloadedIDs(channelName: String) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [] }
        return Set(dict[channelName] ?? [])
    }

    static func addDownloadedID(channelName: String, videoId: String) {
        var dict: [String: [String]] = [:]
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let d = try? JSONDecoder().decode([String: [String]].self, from: data) {
            dict = d
        }
        var ids = dict[channelName] ?? []
        if !ids.contains(videoId) { ids.append(videoId) }
        dict[channelName] = ids
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    static func syncDownloadedIDsFromDisk(channelName: String) {
        let folder = Constants.sanitizeFolderName(channelName)
        let channelDir = "\(Constants.channelStorageDirectory)/\(folder)"
        guard FileManager.default.fileExists(atPath: channelDir),
              let files = try? FileManager.default.contentsOfDirectory(atPath: channelDir)
        else { return }
        var ids = Set<String>()
        for file in files {
            let name = (file as NSString).deletingPathExtension
            guard let dotIndex = name.lastIndex(of: ".") else { continue }
            ids.insert(String(name[name.index(after: dotIndex)...]))
        }
        guard !ids.isEmpty else { return }
        // Merge into UserDefaults
        var dict: [String: [String]] = [:]
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let d = try? JSONDecoder().decode([String: [String]].self, from: data) {
            dict = d
        }
        var existing = Set(dict[channelName] ?? [])
        let newCount = existing.count
        existing.formUnion(ids)
        if existing.count > newCount {
            dict[channelName] = Array(existing)
            guard let data = try? JSONEncoder().encode(dict) else { return }
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    static func saveNewVideoIds(channelId: String, videoIds: [String]) {
        guard !videoIds.isEmpty else { return }
        var dict: [String: [String]] = [:]
        if let data = UserDefaults.standard.data(forKey: newVideosKey),
           let d = try? JSONDecoder().decode([String: [String]].self, from: data) {
            dict = d
        }
        let existing = Set(dict[channelId] ?? [])
        let merged = Array(existing.union(videoIds))
        dict[channelId] = merged
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: newVideosKey)
    }

    static func loadNewVideoIds(channelId: String) -> [String] {
        guard let data = UserDefaults.standard.data(forKey: newVideosKey),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [] }
        return dict[channelId] ?? []
    }

    static func hasNewVideos(channelId: String) -> Bool {
        !loadNewVideoIds(channelId: channelId).isEmpty
    }

    static func clearNewVideoIds(channelId: String) {
        guard let data = UserDefaults.standard.data(forKey: newVideosKey),
              var dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return }
        dict.removeValue(forKey: channelId)
        guard let newData = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(newData, forKey: newVideosKey)
    }

    static func clearAllNewVideoIds() {
        UserDefaults.standard.removeObject(forKey: newVideosKey)
    }

    static func saveSeenVideoIds(channelId: String, videoIds: [String]) {
        guard !videoIds.isEmpty else { return }
        var dict: [String: [String]] = [:]
        if let data = UserDefaults.standard.data(forKey: seenVideosKey),
           let d = try? JSONDecoder().decode([String: [String]].self, from: data) {
            dict = d
        }
        let existing = Set(dict[channelId] ?? [])
        let merged = Array(existing.union(videoIds))
        dict[channelId] = merged
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: seenVideosKey)
    }

    static func loadSeenVideoIds(channelId: String) -> [String] {
        guard let data = UserDefaults.standard.data(forKey: seenVideosKey),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [] }
        return dict[channelId] ?? []
    }

    static func removeSeenVideoIds(channelId: String, videoId: String) {
        guard let data = UserDefaults.standard.data(forKey: seenVideosKey),
              var dict = try? JSONDecoder().decode([String: [String]].self, from: data),
              var ids = dict[channelId],
              let index = ids.firstIndex(of: videoId)
        else { return }
        ids.remove(at: index)
        if ids.isEmpty {
            dict.removeValue(forKey: channelId)
        } else {
            dict[channelId] = ids
        }
        guard let newData = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(newData, forKey: seenVideosKey)
    }

    static var allChannelsWithNewVideos: [String] {
        guard let data = UserDefaults.standard.data(forKey: newVideosKey),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [] }
        return dict.keys.filter { !($0.isEmpty) }
    }

    static func removeDownloadedID(channelName: String, videoId: String) {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              var dict = try? JSONDecoder().decode([String: [String]].self, from: data),
              var ids = dict[channelName],
              let index = ids.firstIndex(of: videoId)
        else { return }
        ids.remove(at: index)
        dict[channelName] = ids
        guard let newData = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(newData, forKey: cacheKey)
    }

    static func removeChannel(_ channelName: String) {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              var dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return }
        dict.removeValue(forKey: channelName)
        guard let newData = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(newData, forKey: cacheKey)
    }

    static func lastFetchDate(channelId: String) -> Date {
        guard let data = UserDefaults.standard.data(forKey: fetchTimestampsKey),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return .distantPast }
        return dict[channelId] ?? .distantPast
    }

    static func markFetchDate(channelId: String) {
        var dict: [String: Date] = [:]
        if let data = UserDefaults.standard.data(forKey: fetchTimestampsKey),
           let d = try? JSONDecoder().decode([String: Date].self, from: data) {
            dict = d
        }
        dict[channelId] = Date()
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: fetchTimestampsKey)
    }

    static func clearFetchDate(channelId: String) {
        guard let data = UserDefaults.standard.data(forKey: fetchTimestampsKey),
              var dict = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        dict.removeValue(forKey: channelId)
        guard let newData = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(newData, forKey: fetchTimestampsKey)
    }
}
