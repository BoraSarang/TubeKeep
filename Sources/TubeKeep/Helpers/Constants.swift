import Foundation

enum Constants {
    static let appName = "TubeKeep"
    static let appGroupSuiteName = "group.com.tubekeep"
    static let defaultResolution = 360
    static let defaultConcurrentDownloads = 2
    static let minConcurrentDownloads = 1
    static let maxConcurrentDownloads = 5
    static let defaultMaxRetries = 3
    static let defaultMaxUploadCheck = 500
    static let defaultStorageDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/TubeKeep").path
    static let defaultFilenameTemplate = "{index} - {title}.{id}"
    static let defaultAX4APIKey = ""
    static let defaultOpenRouterModel = "openrouter/free"

    static var youtubeExtractorArgs: String {
        return "youtube:lang=\(LanguageService.systemLanguageCode)"
    }

    static let settingsSaveKey = "appSettings"

    static let statusBarWidth: CGFloat = 88
    static let statusBarHeight: CGFloat = 22

    static var channelStorageDirectory: String {
        Settings.loadSettings().storageDirectory
    }

    static let openMainWindowNotification = Notification.Name("com.tubekeep.openMainWindow")
    static let openDownloaderWindowNotification = Notification.Name("com.tubekeep.openDownloaderWindow")
    static let openBatchWindowNotification = Notification.Name("com.tubekeep.openBatchWindow")
    static let openChannelWindowNotification = Notification.Name("com.tubekeep.openChannelWindow")
    static let openChannelWithIdNotification = Notification.Name("com.tubekeep.openChannelWithId")
    static let selectChannelNotification = Notification.Name("com.tubekeep.selectChannel")
    static let openSettingsWindowNotification = Notification.Name("com.tubekeep.openSettingsWindow")
    static let openAIWindowNotification = Notification.Name("com.tubekeep.openAIWindow")
    static let openPlayerWindowNotification = Notification.Name("com.tubekeep.openPlayerWindow")
    static let playerSeekNotification = Notification.Name("com.tubekeep.playerSeek")
    static let playerTogglePlayPauseNotification = Notification.Name("com.tubekeep.playerTogglePlayPause")
    static let downloadHistoryDidChangeNotification = Notification.Name("com.tubekeep.downloadHistoryDidChange")
    static let openWhisperSettingsNotification = Notification.Name("com.tubekeep.openWhisperSettings")
    static let videoAIDidChangeNotification = Notification.Name("com.tubekeep.videoAIDidChange")
    static let channelInfoDidUpdateNotification = Notification.Name("com.tubekeep.channelInfoDidUpdate")
    static let libraryDataDidChangeNotification = Notification.Name("com.tubekeep.libraryDataDidChange")

    static let librarySaveKey = "downloadLibrary"
    static let libraryViewModeKey = "libraryViewMode"
    static let channelOrderKey = "channelOrder"
    static let sidebarNavExpandedKey = "sidebarNavExpanded"
    static let downloadQueueKey = "downloadQueue"
    static let showMainWindowOnLaunchKey = "showMainWindowOnLaunch"
    static let sponsorBlockKey = "sponsorBlock"
    static let embedMetadataKey = "embedMetadata"

    static let appcastURL = "https://raw.githubusercontent.com/BoraSarang/TubeKeep/main/appcast.json"

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

    static let ffprobePath: String = {
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("ffprobe").path,
           FileManager.default.fileExists(atPath: bundlePath) {
            return bundlePath
        }
        let candidates = [
            "/usr/local/bin/ffprobe",
            "/opt/homebrew/bin/ffprobe",
            "/usr/bin/ffprobe",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "ffprobe"
    }()

    static var ffmpegDirectory: String {
        if let resourcePath = Bundle.main.resourcePath {
            return resourcePath
        }
        return "/usr/local/bin"
    }

    static var whisperPath: String {
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("whisper-cli").path,
           FileManager.default.fileExists(atPath: bundlePath) {
            return bundlePath
        }
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "whisper-cli"
    }

    static var transcodedCacheDirectory: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.tubekeep/transcoded")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

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
