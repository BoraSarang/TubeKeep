import Foundation
import AppKit

actor LibraryCacheService {
    static let shared = LibraryCacheService()
    private let saveKey = "downloadLibrary"
    private let sharedDefaults = UserDefaults(suiteName: Constants.appGroupSuiteName)

    private var thumbCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 500
        return c
    }()

    private var avatarCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 200
        return c
    }()

    private var cacheDir: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let libDir = dir.appendingPathComponent("com.tubekeep")
        let oldDir = dir.appendingPathComponent("com.mdownload.library")
        if FileManager.default.fileExists(atPath: oldDir.path) && !FileManager.default.fileExists(atPath: libDir.path) {
            try? FileManager.default.moveItem(at: oldDir, to: libDir)
        }
        try? FileManager.default.createDirectory(at: libDir, withIntermediateDirectories: true)
        return libDir
    }

    // MARK: - Library Data

    func loadItems() -> [LibraryItem] {
        let items: [LibraryItem]
        if let data = sharedDefaults?.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([String: LibraryItem].self, from: data) {
            items = Array(decoded.values).sorted { $0.downloadDate > $1.downloadDate }
        } else if let data = UserDefaults.standard.data(forKey: saveKey),
                  let decoded = try? JSONDecoder().decode([String: LibraryItem].self, from: data) {
            sharedDefaults?.set(data, forKey: saveKey)
            items = Array(decoded.values).sorted { $0.downloadDate > $1.downloadDate }
        } else {
            return []
        }

        BookmarkManager.ensureAccess()
        let videoExts = Set(["mp4", "mkv", "webm"])
        let fixed = items.map { item in
            let currentExt = (item.filePath as NSString).pathExtension
            if FileManager.default.fileExists(atPath: item.filePath) && videoExts.contains(currentExt) {
                return item
            }
            let channelDir = "\(Constants.channelStorageDirectory)/\(Constants.sanitizeFolderName(item.channelName))"
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: channelDir) else { return item }
            guard let match = files.first(where: {
                $0.contains(item.id) && videoExts.contains(($0 as NSString).pathExtension)
            }) else { return item }
            var updated = item
            updated.filePath = "\(channelDir)/\(match)"
            return updated
        }

        let changed = zip(items, fixed).contains { $0.filePath != $1.filePath }
        if changed {
            saveItems(fixed)
        }
        return fixed
    }

    func saveItems(_ items: [LibraryItem]) {
        var dict: [String: LibraryItem] = [:]
        for item in items {
            dict[item.id] = item
        }
        guard let data = try? JSONEncoder().encode(dict) else { return }
        sharedDefaults?.set(data, forKey: saveKey)
    }

    func addItem(_ item: LibraryItem) {
        var items = loadItems()
        items.removeAll { $0.id == item.id }
        items.append(item)
        saveItems(items)
    }

    func updateChannelUploadIndices(channelId: String, _ updates: [(videoId: String, uploadIndex: Int)]) {
        let items = loadItems()
        let updated = items.map { item -> LibraryItem in
            guard item.channelId == channelId else { return item }
            if let match = updates.first(where: { $0.videoId == item.id }) {
                return item.withChannelUploadIndex(match.uploadIndex)
            }
            return item
        }
        saveItems(updated)
    }

    func removeItem(id: String) {
        let items = loadItems()
        if let item = items.first(where: { $0.id == id }) {
            BookmarkManager.ensureAccess()
            try? FileManager.default.removeItem(atPath: item.filePath)
            ChannelDownloadCache.removeDownloadedID(channelName: item.channelName, videoId: item.id)
        }
        var updated = items
        updated.removeAll { $0.id == id }
        saveItems(updated)
    }

    func removeItems(ids: [String]) {
        let items = loadItems()
        for item in items where ids.contains(item.id) {
            BookmarkManager.ensureAccess()
            try? FileManager.default.removeItem(atPath: item.filePath)
            ChannelDownloadCache.removeDownloadedID(channelName: item.channelName, videoId: item.id)
        }
        var updated = items
        updated.removeAll { ids.contains($0.id) }
        saveItems(updated)
    }

    // MARK: - Channel Names

    func channelNames(from items: [LibraryItem]) -> [(id: String, name: String, count: Int)] {
        var dict: [String: (name: String, count: Int)] = [:]
        for item in items {
            if var existing = dict[item.channelId] {
                existing.count += 1
                dict[item.channelId] = existing
            } else {
                dict[item.channelId] = (item.channelName, 1)
            }
        }
        return dict.map { (id: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // MARK: - Thumbnail Cache

    func cachedThumbnail(for videoId: String) -> NSImage? {
        let key = "thumb_\(videoId)" as NSString
        if let cached = thumbCache.object(forKey: key) { return cached }
        guard let dir = cacheDir else { return nil }
        let file = dir.appendingPathComponent("thumb_\(videoId).jpg")
        guard let data = try? Data(contentsOf: file), let img = NSImage(data: data) else { return nil }
        thumbCache.setObject(img, forKey: key)
        return img
    }

    func cacheThumbnail(for videoId: String, data: Data) {
        let key = "thumb_\(videoId)" as NSString
        if let img = NSImage(data: data) {
            thumbCache.setObject(img, forKey: key)
        }
        guard let dir = cacheDir else { return }
        let file = dir.appendingPathComponent("thumb_\(videoId).jpg")
        try? data.write(to: file)
    }

    func loadThumbnail(from url: String, videoId: String) async -> Data? {
        if let cached = cachedThumbnail(for: videoId),
           let data = cached.tiffRepresentation { return data }
        guard let url = URL(string: url) else { return nil }
        do {
            let req = URLRequest(url: url, timeoutInterval: 10)
            let (data, _) = try await URLSession.shared.data(for: req)
            cacheThumbnail(for: videoId, data: data)
            return data
        } catch {
            return nil
        }
    }

    // MARK: - Avatar Cache

    func cachedAvatar(for channelId: String) -> NSImage? {
        let key = "avatar_\(channelId)" as NSString
        if let cached = avatarCache.object(forKey: key) { return cached }
        guard let dir = cacheDir else { return nil }
        let file = dir.appendingPathComponent("avatar_\(channelId).jpg")
        guard let data = try? Data(contentsOf: file), let img = NSImage(data: data) else { return nil }
        avatarCache.setObject(img, forKey: key)
        return img
    }

    func cacheAvatar(for channelId: String, data: Data) {
        let key = "avatar_\(channelId)" as NSString
        if let img = NSImage(data: data) {
            avatarCache.setObject(img, forKey: key)
        }
        guard let dir = cacheDir else { return }
        let file = dir.appendingPathComponent("avatar_\(channelId).jpg")
        try? data.write(to: file)
    }

    func loadAvatar(from url: String, channelId: String) async -> Data? {
        if let cached = cachedAvatar(for: channelId),
           let data = cached.tiffRepresentation { return data }
        guard let url = URL(string: url) else { return nil }
        do {
            let req = URLRequest(url: url, timeoutInterval: 10)
            let (data, _) = try await URLSession.shared.data(for: req)
            cacheAvatar(for: channelId, data: data)
            return data
        } catch {
            return nil
        }
    }

    nonisolated func placeholderAvatar() -> NSImage {
        let img = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
            ?? NSImage()
        img.size = NSSize(width: 20, height: 20)
        return img
    }

    nonisolated func placeholderThumbnail() -> NSImage {
        let img = NSImage(systemSymbolName: "film", accessibilityDescription: nil)
            ?? NSImage()
        img.size = NSSize(width: 320, height: 180)
        return img
    }

    nonisolated static func calculateDiskUsage() -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0

        let dirs = [
            Constants.channelStorageDirectory,
            (try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
                .flatMap { $0.appendingPathComponent("com.tubekeep").path }
        ].compactMap { $0 }

        for dir in dirs {
            guard fm.fileExists(atPath: dir) else { continue }
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let fileURL as URL in enumerator {
                guard let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                      let size = attrs.fileSize
                else { continue }
                total += Int64(size)
            }
        }
        return total
    }
}
