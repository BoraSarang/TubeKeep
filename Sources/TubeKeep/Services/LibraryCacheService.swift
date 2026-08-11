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

    func clearDerivedAI() {
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [])
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            item.tags = []
            item.summary = nil
            item.transcript = nil
            item.chapters = nil
            item.subtitleLanguage = nil
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

    // MARK: - Trash (v3.5 휴지통)

    private struct TrashOriginalPath: Codable {
        let originalPath: String
    }

    var trashDirectory: String {
        "\(Constants.channelStorageDirectory)/.Trash"
    }

    func trashedItems() -> [LibraryItem] {
        let descriptor = FetchDescriptor<LibraryItem>(sortBy: [SortDescriptor(\.trashedAt, order: .reverse)])
        guard let items = try? context.fetch(descriptor) else { return [] }
        return items.filter { $0.trashedAt != nil }
    }

    func trashItem(id: String) -> Bool {
        guard let item = findItem(id: id) else { return false }
        BookmarkManager.ensureAccess()
        let fm = FileManager.default
        let trashDir = (trashDirectory as NSString).appendingPathComponent(item.id)
        guard fm.fileExists(atPath: item.filePath), !fm.fileExists(atPath: trashDir) else {
            item.trashedAt = Date()
            try? context.save()
            return true
        }
        do {
            try fm.createDirectory(atPath: trashDir, withIntermediateDirectories: true)
            let fileName = (item.filePath as NSString).lastPathComponent
            let dest = (trashDir as NSString).appendingPathComponent(fileName)
            let sidecar = try JSONEncoder().encode(TrashOriginalPath(originalPath: item.filePath))
            try sidecar.write(to: URL(fileURLWithPath: (trashDir as NSString).appendingPathComponent("original_path.json")))
            try fm.moveItem(atPath: item.filePath, toPath: dest)
            item.filePath = dest
        } catch {
            DebugLogManager.shared?.append("[Library] 휴지통 이동 실패: \(error)")
            return false
        }
        item.trashedAt = Date()
        try? context.save()
        ChannelDownloadCache.removeDownloadedID(channelName: item.channelName, videoId: item.id)
        return true
    }

    func trashItems(ids: [String]) -> [String] {
        var moved: [String] = []
        for id in ids where trashItem(id: id) {
            moved.append(id)
        }
        return moved
    }

    func restoreItem(id: String) -> Bool {
        guard let item = findItem(id: id), item.trashedAt != nil else { return false }
        BookmarkManager.ensureAccess()
        let fm = FileManager.default
        let trashDir = (trashDirectory as NSString).appendingPathComponent(item.id)
        let sidecarPath = (trashDir as NSString).appendingPathComponent("original_path.json")
        var original = item.filePath
        if let data = try? Data(contentsOf: URL(fileURLWithPath: sidecarPath)),
           let decoded = try? JSONDecoder().decode(TrashOriginalPath.self, from: data) {
            original = decoded.originalPath
        }
        do {
            let parent = (original as NSString).deletingLastPathComponent
            try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
            if fm.fileExists(atPath: item.filePath) {
                try fm.moveItem(atPath: item.filePath, toPath: original)
            }
        } catch {
            DebugLogManager.shared?.append("[Library] 휴지통 복원 실패: \(error)")
            return false
        }
        item.filePath = original
        item.trashedAt = nil
        try? context.save()
        ChannelDownloadCache.addDownloadedID(channelName: item.channelName, videoId: item.id)
        return true
    }

    func restoreItems(ids: [String]) -> [String] {
        var restored: [String] = []
        for id in ids where restoreItem(id: id) {
            restored.append(id)
        }
        return restored
    }

    func permanentlyDeleteItem(id: String) {
        guard findItem(id: id) != nil else { return }
        DatabaseManager.shared.deleteDownloadHistory(videoId: id)
        removeItem(id: id)
    }

    func emptyTrash() {
        let items = trashedItems()
        for item in items {
            DatabaseManager.shared.deleteDownloadHistory(videoId: item.id)
            removeItem(id: item.id)
        }
    }

    func autoPurgeTrash(olderThan days: Int = 30) {
        let cutoff = Date().addingTimeInterval(-TimeInterval(days * 24 * 3600))
        let items = trashedItems()
        var purged = 0
        for item in items {
            if let trashedAt = item.trashedAt, trashedAt < cutoff {
                DatabaseManager.shared.deleteDownloadHistory(videoId: item.id)
                removeItem(id: item.id)
                purged += 1
            }
        }
        if purged > 0 {
            DebugLogManager.shared?.append("[Trash] \(days)일 경과 휴지통 \(purged)개 자동 정리")
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

    // MARK: - Playback Position (이어보기)

    func updatePlaybackPosition(videoId: String, position: Double) {
        guard let item = findItem(id: videoId), position > 0 else { return }
        item.lastPlaybackPosition = position
        item.lastPlayedAt = Date()
        do {
            try context.save()
        } catch {
            DebugLogManager.shared?.append("[Library] 이어보기 위치 저장 실패: \(error)")
        }
    }

    func clearPlaybackPosition(videoId: String) {
        guard let item = findItem(id: videoId) else { return }
        item.lastPlaybackPosition = nil
        item.lastPlayedAt = nil
        do {
            try context.save()
        } catch {
            DebugLogManager.shared?.append("[Library] 이어보기 위치 초기화 실패: \(error)")
        }
    }

    // MARK: - Channel Names

    func channelNames(from items: [LibraryItem]) -> [(id: String, name: String, count: Int, avatarURL: String)] {
        var dict: [String: (name: String, count: Int)] = [:]
        for item in items {
            if var existing = dict[item.channelId] {
                existing.count += 1
                dict[item.channelId] = existing
            } else {
                dict[item.channelId] = (item.channelName, 1)
            }
        }

        // 채널명 토큰 기반 병합 — 동일 채널이 실제 ID/핸들 형식으로 중복 저장된 경우를 하나로 합침
        let entries = dict.map { (id: $0.key, name: $0.value.name, count: $0.value.count) }
        var merged: [ChannelNameEntry] = []
        for entry in entries {
            if let idx = merged.firstIndex(where: { nameTokensMatch($0.name, entry.name) }) {
                // 실제 UC ID(24자)가 있으면 그것을 우선 키로 사용
                merged[idx].id = Self.isRealChannelID(entry.id) ? entry.id : merged[idx].id
                merged[idx].name = entry.name
                merged[idx].count += entry.count
            } else {
                merged.append(ChannelNameEntry(id: entry.id, name: entry.name, count: entry.count))
            }
        }

        let avatarURLs = Dictionary(uniqueKeysWithValues: SubscribedChannel.loadAll().map { ($0.id, $0.avatarURL) })
        return merged.map { (id: $0.id, name: $0.name, count: $0.count, avatarURL: avatarURLs[$0.id] ?? "") }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private struct ChannelNameEntry {
        var id: String
        var name: String
        var count: Int
    }

    /// 두 채널 이름의 유효 토큰(한글/영문 단어) 공통 여부 확인 — 공통 토큰 2개 이상이거나 이름 동일 시 매칭
    nonisolated static func nameTokensMatch(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        let tokensA = Set(nameTokens(a))
        let tokensB = Set(nameTokens(b))
        guard tokensA.count >= 2, tokensB.count >= 2 else {
            return false
        }
        return tokensA.intersection(tokensB).count >= 2
    }

    /// 두 채널 이름의 유효 토큰(한글/영문 단어) 공통 여부 확인 — 공통 토큰 2개 이상이거나 이름 동일 시 매칭
    func nameTokensMatch(_ a: String, _ b: String) -> Bool {
        Self.nameTokensMatch(a, b)
    }

    private nonisolated static func nameTokens(_ name: String) -> [String] {
        var tokens: Set<String> = []
        let regex = try? NSRegularExpression(pattern: "[\\p{L}\\p{N}]{2,}")
        if let regex {
            let ns = name as NSString
            for match in regex.matches(in: name, range: NSRange(location: 0, length: ns.length)) {
                tokens.insert(ns.substring(with: match.range).lowercased())
            }
        }
        return Array(tokens)
    }

    // MARK: - Channel ID Normalization

    /// 실제 YouTube 채널 ID(UC + 22자 = 24자, 핸들 형식 UC_.. 제외) 여부
    nonisolated static func isRealChannelID(_ id: String) -> Bool {
        id.hasPrefix("UC") && id.count == 24
    }

    /// 채널 ID 교정: 실제 UC ID(24자)면 그대로, 아니면 기존 값 유지.
    /// 아이템/구독에서 실제 ID를 우선 키로 쓸 수 있도록 한다.
    nonisolated static func normalizeChannelID(_ id: String, prefer candidates: [String] = []) -> String {
        if isRealChannelID(id) { return id }
        // 서로 다른 저장소에 실제 UC ID가 있으면 그것을 우선
        if let real = candidates.first(where: { isRealChannelID($0) }) { return real }
        return id
    }

    /// 잘못 저장된 핸들 형식(UC_..) 채널 ID를 채널명 토큰 매칭으로 실제 UC ID로 복구한다.
    /// - 보관함(LibraryItem.channelId)과 구독(SubscribedChannel.id) 모두 대상.
    @discardableResult
    func migrateChannelIDs() -> (items: Int, channels: Int) {
        let pairs = (try? context.fetch(FetchDescriptor<LibraryItem>(sortBy: [])))?
            .compactMap { item -> (String, String)? in
                guard Self.isRealChannelID(item.channelId) else { return nil }
                return (item.channelName, item.channelId)
            } ?? []
        let realByToken = Dictionary(pairs, uniquingKeysWith: { first, _ in first })

        var itemFix = 0
        let items = (try? context.fetch(FetchDescriptor<LibraryItem>(sortBy: []))) ?? []
        for item in items where !Self.isRealChannelID(item.channelId) {
            if let real = realByToken.first(where: { nameTokensMatch($0.key, item.channelName) })?.value {
                item.channelId = real
                itemFix += 1
            }
        }

        var channelFix = 0
        let channels = SubscribedChannel.loadAll()
        for channel in channels where !Self.isRealChannelID(channel.id) {
            if let real = realByToken.first(where: { nameTokensMatch($0.key, channel.name) })?.value {
                channel.id = real
                channelFix += 1
            }
        }

        if itemFix > 0 { try? context.save() }
        if channelFix > 0 { SubscribedChannel.saveAll(channels) }
        if itemFix + channelFix > 0 {
            DebugLogManager.shared?.append("[Channel] 🪄 채널 ID 마이그레이션: items \(itemFix)개, channels \(channelFix)개")
        }
        return (itemFix, channelFix)
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
