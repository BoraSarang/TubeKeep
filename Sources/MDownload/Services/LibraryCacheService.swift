import Foundation
import AppKit

actor LibraryCacheService {
    static let shared = LibraryCacheService()
    private let saveKey = "downloadLibrary"

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
        let libDir = dir.appendingPathComponent("com.mdownload.library")
        try? FileManager.default.createDirectory(at: libDir, withIntermediateDirectories: true)
        return libDir
    }

    // MARK: - Library Data

    func loadItems() -> [LibraryItem] {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let items = try? JSONDecoder().decode([String: LibraryItem].self, from: data)
        else { return [] }
        return Array(items.values).sorted { $0.downloadDate > $1.downloadDate }
    }

    func saveItems(_ items: [LibraryItem]) {
        var dict: [String: LibraryItem] = [:]
        for item in items {
            dict[item.id] = item
        }
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    func addItem(_ item: LibraryItem) {
        var items = loadItems()
        items.removeAll { $0.id == item.id }
        items.append(item)
        saveItems(items)
    }

    func removeItem(id: String) {
        var items = loadItems()
        items.removeAll { $0.id == id }
        saveItems(items)
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
}
