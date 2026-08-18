import AppKit
import Foundation
import os

enum BookmarkManager {
    private static let lock = OSAllocatedUnfairLock()
    private static var activeURLs: [String: URL] = [:]
    private static let storageDirKey = "storageDirectoryBookmark"
    private static var accessFailureLogged = false

    static func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: storageDirKey)
            lock.lock()
            activeURLs[storageDirKey] = url
            lock.unlock()
            DebugLogManager.shared?.append("[STORAGE] 북마크 저장 성공: \(url.path)")
        } catch {
            DebugLogManager.shared?.append("[ERROR] E-MAC-STOR-1001 북마크 생성 실패: \(url.path) — \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func ensureAccess() -> Bool {
        lock.lock()
        let existing = activeURLs[storageDirKey]
        lock.unlock()
        if existing != nil { return true }

        guard let data = UserDefaults.standard.data(forKey: storageDirKey) else {
            DebugLogManager.shared?.append("[STORAGE] ensureAccess: 북마크 없음 → 저장 폴더 재선택 필요")
            return false
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            guard let fallback = try? URL(
                resolvingBookmarkData: data,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                if !accessFailureLogged {
                    accessFailureLogged = true
                    DebugLogManager.shared?.append("[ERROR] E-MAC-STOR-1001 북마크 복원 실패")
                }
                return false
            }
            url = fallback
        }

        guard url.startAccessingSecurityScopedResource() else {
            if !accessFailureLogged {
                accessFailureLogged = true
                DebugLogManager.shared?.append("[ERROR] E-MAC-STOR-1001 접근 시작 실패: \(url.path)")
            }
            return false
        }
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

    static func promptReselectStorageDirectoryIfNeeded() {
        let settings = Settings.loadSettings()
        guard settings.storageDirectory != Constants.defaultStorageDirectory else { return }
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.message = "저장 폴더 접근 권한이 만료되었습니다.\n저장 폴더를 다시 선택해 주세요."
            let last = URL(fileURLWithPath: settings.storageDirectory)
            if FileManager.default.fileExists(atPath: last.path) {
                panel.directoryURL = last
            }
            guard panel.runModal() == .OK, let url = panel.url else {
                DebugLogManager.shared?.append("[STORAGE] 저장 폴더 재선택 취소됨")
                return
            }
            refreshBookmark(for: url)
            if url.path != settings.storageDirectory {
                var updated = settings
                updated.storageDirectory = url.path
                if let data = try? JSONEncoder().encode(updated),
                   let json = String(data: data, encoding: .utf8) {
                    UserDefaults.standard.set(json, forKey: Constants.settingsSaveKey)
                }
            }
            DebugLogManager.shared?.append("[STORAGE] 저장 폴더 재선택 완료: \(url.path)")
        }
    }

    static func stopAccessing() {
        lock.lock()
        let url = activeURLs.removeValue(forKey: storageDirKey)
        lock.unlock()
        url?.stopAccessingSecurityScopedResource()
    }
}
