import Foundation

enum BookmarkManager {
    private static var activeURLs: [String: URL] = [:]
    private static let storageDirKey = "storageDirectoryBookmark"

    static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: storageDirKey)
        activeURLs[storageDirKey] = url
    }

    @discardableResult
    static func ensureAccess() -> Bool {
        if activeURLs[storageDirKey] != nil { return true }

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
        activeURLs[storageDirKey] = url
        return true
    }

    static func refreshBookmark(for url: URL) {
        stopAccessing()
        saveBookmark(for: url)
        _ = url.startAccessingSecurityScopedResource()
        activeURLs[storageDirKey] = url
    }

    static func stopAccessing() {
        if let url = activeURLs.removeValue(forKey: storageDirKey) {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
