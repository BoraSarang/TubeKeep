import Foundation

enum SettingsTab: String, Equatable, CaseIterable {
    case downloads = "일반"
    case storage = "저장"
    case other = "시스템"
    case ai = "AI 요약"

    var icon: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .storage: return "folder"
        case .other: return "gearshape"
        case .ai: return "sparkle"
        }
    }
}

struct Settings: Equatable, Codable {
    var concurrentDownloads: Int = Constants.defaultConcurrentDownloads
    var storageDirectory: String = Constants.defaultStorageDirectory
    var filenameTemplate: String = Constants.defaultFilenameTemplate
    var limitRate: Int = 0
    var playSoundOnComplete: Bool = true
    var clipboardMonitoring: Bool = true
    var showOnlyVideo: Bool = true
    var defaultResolution: Int = Constants.defaultResolution
    var maxRetries: Int = Constants.defaultMaxRetries
    var launchAtLogin: Bool = false
    var maxUploadCheck: Int = Constants.defaultMaxUploadCheck
    var skipIndexOnFailure: Bool = false
    var geminiAPIKey: String = ""
    var showMainWindowOnLaunch: Bool = true
    var sponsorBlock: Bool = true
    var embedMetadata: Bool = true

    enum CodingKeys: String, CodingKey {
        case concurrentDownloads, filenameTemplate, limitRate
        case playSoundOnComplete, clipboardMonitoring, showOnlyVideo
        case defaultResolution, maxRetries, launchAtLogin, maxUploadCheck, skipIndexOnFailure
        case storageDirectory = "outputDirectory", geminiAPIKey, showMainWindowOnLaunch
        case sponsorBlock, embedMetadata
    }

    var limitRateArg: String? {
        guard limitRate > 0 else { return nil }
        return "\(limitRate)M"
    }
}
