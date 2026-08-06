import Foundation
import AppKit
import SwiftData

@MainActor
final class LibraryCacheService {
    static let shared = LibraryCacheService()

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

    private var context: ModelContext {
        PersistenceController.shared.context
    }

    // MARK: - Library Data

    func loadItems() -> [LibraryItem] {
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [SortDescriptor(\.downloadDate, order: .reverse)])
        guard let items = try? context.fetch(descriptor) else { return [] }

        BookmarkManager.ensureAccess()
        let videoExts = Set(["mp4", "m4a", "mkv", "webm"])
        var changed = false
        let fixed = items.map { item -> LibraryItem in
            let currentExt = (item.filePath as NSString).pathExtension
            if FileManager.default.fileExists(atPath: item.filePath) && videoExts.contains(currentExt) {
                return item
            }
            let channelDir = "\(Constants.channelStorageDirectory)/\(Constants.sanitizeFolderName(item.channelName))"
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: channelDir) else { return item }
            guard let match = files.first(where: {
                $0.contains(item.id) && videoExts.contains(($0 as NSString).pathExtension)
            }) else { return item }
            item.filePath = "\(channelDir)/\(match)"
            changed = true
            return item
        }

        if changed {
            try? context.save()
        }
        return fixed
    }

    func addItem(_ item: LibraryItem) {
        if let existing = findItem(id: item.id) {
            context.delete(existing)
        }
        context.insert(item)
        try? context.save()
    }

    func updateItem(_ item: LibraryItem) {
        if let existing = findItem(id: item.id) {
            existing.title = item.title
            existing.channelId = item.channelId
            existing.channelName = item.channelName
            existing.thumbnailURL = item.thumbnailURL
            existing.filePath = item.filePath
            existing.downloadDate = item.downloadDate
            existing.uploadDate = item.uploadDate
            existing.duration = item.duration
            existing.channelUploadIndex = item.channelUploadIndex
            existing.tags = item.tags
            existing.summary = item.summary
            existing.transcript = item.transcript
            existing.chapters = item.chapters
            existing.subtitleLanguage = item.subtitleLanguage
        } else {
            context.insert(item)
        }
        try? context.save()
    }

    func updateChannelUploadIndices(channelId: String, _ updates: [(videoId: String, uploadIndex: Int)]) {
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [])
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items where item.channelId == channelId {
            if let match = updates.first(where: { $0.videoId == item.id }) {
                item.channelUploadIndex = match.uploadIndex
            }
        }
        try? context.save()
    }

    func removeItem(id: String) {
        if let item = findItem(id: id) {
            guard ClipService.confirmAndDeleteClipsIfAny(for: item.id) else { return }
            BookmarkManager.ensureAccess()
            try? FileManager.default.removeItem(atPath: item.filePath)
            ChannelDownloadCache.removeDownloadedID(channelName: item.channelName, videoId: item.id)
            context.delete(item)
            do {
                try context.save()
            } catch {
                DebugLogManager.shared?.append("[Library] removeItem 저장 실패: \(error)")
            }
            purgeAssociatedData(for: item.id)
        }
    }

    func removeItems(ids: [String]) {
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [])
        guard let items = try? context.fetch(descriptor) else { return }
        var removed: [String] = []
        for item in items where idSet.contains(item.id) {
            guard ClipService.confirmAndDeleteClipsIfAny(for: item.id) else { continue }
            BookmarkManager.ensureAccess()
            try? FileManager.default.removeItem(atPath: item.filePath)
            ChannelDownloadCache.removeDownloadedID(channelName: item.channelName, videoId: item.id)
            context.delete(item)
            removed.append(item.id)
        }
        do {
            try context.save()
        } catch {
            DebugLogManager.shared?.append("[Library] removeItems 저장 실패: \(error)")
        }
        for id in removed {
            purgeAssociatedData(for: id)
        }
    }

    private func purgeAssociatedData(for videoId: String) {
        DatabaseManager.shared.deleteVideoAIData(videoId: videoId)
        DatabaseManager.shared.deleteAllQAHistory(videoId: videoId)
        DatabaseManager.shared.deleteFTSIndex(videoId: videoId)
        thumbCache.removeObject(forKey: "thumb_\(videoId)" as NSString)
        guard let dir = cacheDir else { return }
        let thumbFile = dir.appendingPathComponent("thumb_\(videoId).jpg")
        try? FileManager.default.removeItem(at: thumbFile)
    }

    func findItem(id: String) -> LibraryItem? {
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [])
        guard let items = try? context.fetch(descriptor) else { return nil }
        return items.first { $0.id == id }
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

    func clearAvatarCache(for channelId: String) {
        let key = "avatar_\(channelId)" as NSString
        avatarCache.removeObject(forKey: key)
        guard let dir = cacheDir else { return }
        let file = dir.appendingPathComponent("avatar_\(channelId).jpg")
        try? FileManager.default.removeItem(at: file)
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

        let podcastDir = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/TubeKeep/Podcasts")
        let cacheDir = (try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            .flatMap { $0.appendingPathComponent("com.tubekeep").path }
        var dirs: [String] = [Constants.channelStorageDirectory, podcastDir]
        if let cacheDir { dirs.append(cacheDir) }

        for dir in dirs {
            guard fm.fileExists(atPath: dir) else { continue }
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [URLResourceKey.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let fileURL as URL in enumerator {
                guard let attrs = try? fileURL.resourceValues(forKeys: [URLResourceKey.fileSizeKey]),
                      let size = attrs.fileSize
                else { continue }
                total += Int64(size)
            }
        }
        return total
    }
}
