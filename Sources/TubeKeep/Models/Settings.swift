import Foundation

enum TTSEngine: String, CaseIterable, Codable, Equatable {
    case apple = "macOS 내장"
    case edgeTTS = "Edge TTS"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .apple: return "오프라인, 무료, 제한 없음"
        case .edgeTTS: return "무료, 무제한, 고품질 (Microsoft)"
        }
    }

    var maleVoice: String {
        switch self {
        case .apple: return "com.apple.eloquence.ko-KR.Reed"
        case .edgeTTS: return "ko-KR-InJoonNeural"
        }
    }

    var femaleVoice: String {
        switch self {
        case .apple: return "com.apple.voice.super-compact.ko-KR.Yuna"
        case .edgeTTS: return "ko-KR-SunHiNeural"
        }
    }
}

enum SettingsTab: String, Equatable, CaseIterable {
    case downloads = "일반"
    case storage = "저장"
    case other = "시스템"
    case ai = "AI 설정"

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
    var openRouterAPIKey: String = ""
    var openRouterModel: String = "openrouter/free"
    var geminiAPIKey: String = ""
    var ax4APIKey: String = Constants.defaultAX4APIKey
    var showMainWindowOnLaunch: Bool = true
    var sponsorBlock: Bool = true
    var embedMetadata: Bool = true
    var showThumbnailPreview: Bool = true
    var ttsEngine: TTSEngine = .apple

    enum CodingKeys: String, CodingKey {
        case concurrentDownloads, filenameTemplate, limitRate
        case playSoundOnComplete, clipboardMonitoring, showOnlyVideo
        case defaultResolution, maxRetries, launchAtLogin, maxUploadCheck, skipIndexOnFailure
        case storageDirectory = "outputDirectory", openRouterAPIKey, openRouterModel, geminiAPIKey, ax4APIKey, showMainWindowOnLaunch
        case sponsorBlock, embedMetadata, showThumbnailPreview, ttsEngine
    }

    var limitRateArg: String? {
        guard limitRate > 0 else { return nil }
        return "\(limitRate)M"
    }
}
