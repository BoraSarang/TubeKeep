import Foundation

enum Constants {
    static let appName = "TubeKeep"
    static let appGroupSuiteName = "com.tubekeep.shared"
    static let defaultResolution = 480
    static let defaultConcurrentDownloads = 2
    static let minConcurrentDownloads = 1
    static let maxConcurrentDownloads = 5
    static let defaultMaxRetries = 3
    static let defaultMaxUploadCheck = 500
    static let defaultStorageDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/TubeKeep").path
    static let defaultFilenameTemplate = "{index} - {title}.{id}"

    static var youtubeExtractorArgs: String {
        let lang = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        return "youtube:lang=\(lang)"
    }

    static let settingsSaveKey = "appSettings"

    static let statusBarWidth: CGFloat = 88
    static let statusBarHeight: CGFloat = 22

    static var channelStorageDirectory: String {
        guard let json = UserDefaults.standard.string(forKey: settingsSaveKey),
              let data = json.data(using: .utf8),
              let s = try? JSONDecoder().decode(Settings.self, from: data)
        else { return defaultStorageDirectory }
        return s.storageDirectory
    }

    static let openMainWindowNotification = Notification.Name("com.tubekeep.openMainWindow")
    static let openDownloaderWindowNotification = Notification.Name("com.tubekeep.openDownloaderWindow")
    static let openBatchWindowNotification = Notification.Name("com.tubekeep.openBatchWindow")
    static let openChannelWindowNotification = Notification.Name("com.tubekeep.openChannelWindow")
    static let openChannelWithIdNotification = Notification.Name("com.tubekeep.openChannelWithId")
    static let selectChannelNotification = Notification.Name("com.tubekeep.selectChannel")
    static let librarySaveKey = "downloadLibrary"
    static let libraryViewModeKey = "libraryViewMode"
    static let channelOrderKey = "channelOrder"
    static let downloadQueueKey = "downloadQueue"

    static func isChannelURL(_ url: String) -> Bool {
        let patterns = [
            #"^(https?://)?(www\.)?youtube\.com/@[a-zA-Z0-9_-]+(/videos)?(/shorts)?(/streams)?$"#,
            #"^(https?://)?(www\.)?youtube\.com/channel/UC[a-zA-Z0-9_-]+"#,
            #"^(https?://)?(www\.)?youtube\.com/c/[a-zA-Z0-9_-]+"#,
        ]
        return patterns.contains { pattern in
            url.range(of: pattern, options: .regularExpression) != nil
        }
    }

    static func channelIDFromURL(_ url: String) -> String? {
        // Direct channel ID: youtube.com/channel/UCxxx
        if let range = url.range(of: #"youtube\.com/channel/(UC[a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let matched = url[range]
            if let slash = matched.lastIndex(of: "/") {
                return String(matched[matched.index(after: slash)...])
            }
        }
        // Handle/custom URL: need yt-dlp resolution, return nil here
        return nil
    }

    static func sanitizeFolderName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(.init(charactersIn: "-_.()[]가-힣"))
        return String(name.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let ytDlpPath: String = {
        // Bundled path first
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("yt-dlp").path,
           FileManager.default.fileExists(atPath: bundlePath) {
            return bundlePath
        }
        let paths = [
            "/usr/local/bin/yt-dlp",
            "/opt/homebrew/bin/yt-dlp",
            "/usr/bin/yt-dlp",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "yt-dlp"
    }()

    static let ffmpegPath: String = {
        // Bundled path first
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("ffmpeg").path,
           FileManager.default.fileExists(atPath: bundlePath) {
            return bundlePath
        }
        let paths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "ffmpeg"
    }()
}
