import Foundation
import os

enum BookmarkManager {
    private static let lock = OSAllocatedUnfairLock()
    private static var activeURLs: [String: URL] = [:]
    private static let storageDirKey = "storageDirectoryBookmark"

    static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: storageDirKey)
        lock.lock()
        activeURLs[storageDirKey] = url
        lock.unlock()
    }

    @discardableResult
    static func ensureAccess() -> Bool {
        lock.lock()
        let existing = activeURLs[storageDirKey]
        lock.unlock()
        if existing != nil { return true }

        guard let data = UserDefaults.standard.data(forKey: storageDirKey) else { return false }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return false }

        if isStale {
            saveBookmark(for: url)
        }

        guard url.startAccessingSecurityScopedResource() else { return false }
        lock.lock()
        activeURLs[storageDirKey] = url
        lock.unlock()
        return true
    }

    static func refreshBookmark(for url: URL) {
        stopAccessing()
        saveBookmark(for: url)
        _ = url.startAccessingSecurityScopedResource()
        lock.lock()
        activeURLs[storageDirKey] = url
        lock.unlock()
    }

    static func stopAccessing() {
        lock.lock()
        let url = activeURLs.removeValue(forKey: storageDirKey)
        lock.unlock()
        url?.stopAccessingSecurityScopedResource()
    }
}
