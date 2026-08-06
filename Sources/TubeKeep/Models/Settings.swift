import Foundation

enum PlayerMode: String, CaseIterable, Codable, Equatable {
    case builtIn = "자체 플레이어"
    case systemDefault = "기본 연결 프로그램"
}

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
    case downloads = "다운로드"
    case storage = "저장"
    case notifications = "알림"
    case system = "시스템"
    case ai = "AI 설정"

    var icon: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .storage: return "folder"
        case .notifications: return "bell"
        case .system: return "gearshape"
        case .ai: return "sparkle"
        }
    }
}

enum WhisperModelStatus: String, Equatable {
    case unknown
    case notInstalled
    case downloading
    case installed
    case error
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
    var ttsEngine: TTSEngine = .edgeTTS
    var playerMode: PlayerMode = .builtIn
    var showChannelBadge: Bool = true
    var subtitleLanguageOverride: String = ""
    var enableWhisperTranscription: Bool = false
    var whisperModelSize: String = "base"
    var showMenuBarNotifications: Bool = true
    var menuBarNotificationDuration: Int = 60
    var presets: [DownloadPreset] = Self.defaultPresets
    var activePresetId: UUID?
    var smartMode: Bool = false
    var seekStepSeconds: Double = 5.0
    var idleAutoSummary: Bool = true
    var idleAutoPodcast: Bool = false

    static let defaultPresets: [DownloadPreset] = [
        DownloadPreset(id: UUID(), name: "고품질 (4K)", formatType: .video,
                       resolution: 2160, includeSubtitles: true,
                       sponsorBlock: true, embedMetadata: true),
        DownloadPreset(id: UUID(), name: "기본 (1080p)", formatType: .video,
                       resolution: 1080, includeSubtitles: true,
                       sponsorBlock: true, embedMetadata: true),
        DownloadPreset(id: UUID(), name: "오디오만", formatType: .audio,
                       resolution: 0, includeSubtitles: false,
                       sponsorBlock: false, embedMetadata: false),
    ]

    enum CodingKeys: String, CodingKey {
        case concurrentDownloads, filenameTemplate, limitRate
        case playSoundOnComplete, clipboardMonitoring, showOnlyVideo
        case defaultResolution, maxRetries, launchAtLogin, maxUploadCheck, skipIndexOnFailure
        case storageDirectory = "outputDirectory", openRouterAPIKey, openRouterModel, geminiAPIKey, ax4APIKey, showMainWindowOnLaunch
        case sponsorBlock, embedMetadata, showThumbnailPreview, ttsEngine, playerMode, showChannelBadge
        case subtitleLanguageOverride, enableWhisperTranscription, whisperModelSize
        case showMenuBarNotifications, menuBarNotificationDuration, presets, activePresetId, smartMode
        case seekStepSeconds, idleAutoSummary, idleAutoPodcast
    }

    init(
        concurrentDownloads: Int = Constants.defaultConcurrentDownloads,
        storageDirectory: String = Constants.defaultStorageDirectory,
        filenameTemplate: String = Constants.defaultFilenameTemplate,
        limitRate: Int = 0,
        playSoundOnComplete: Bool = true,
        clipboardMonitoring: Bool = true,
        showOnlyVideo: Bool = true,
        defaultResolution: Int = Constants.defaultResolution,
        maxRetries: Int = Constants.defaultMaxRetries,
        launchAtLogin: Bool = false,
        maxUploadCheck: Int = Constants.defaultMaxUploadCheck,
        skipIndexOnFailure: Bool = false,
        openRouterAPIKey: String = "",
        openRouterModel: String = "openrouter/free",
        geminiAPIKey: String = "",
        ax4APIKey: String = Constants.defaultAX4APIKey,
        showMainWindowOnLaunch: Bool = true,
        sponsorBlock: Bool = true,
        embedMetadata: Bool = true,
        showThumbnailPreview: Bool = true,
        ttsEngine: TTSEngine = .edgeTTS,
        playerMode: PlayerMode = .builtIn,
        showChannelBadge: Bool = true,
        subtitleLanguageOverride: String = "",
        enableWhisperTranscription: Bool = false,
        whisperModelSize: String = "base",
        showMenuBarNotifications: Bool = true,
        menuBarNotificationDuration: Int = 60,
        presets: [DownloadPreset] = Self.defaultPresets,
        activePresetId: UUID? = nil,
        smartMode: Bool = false,
        seekStepSeconds: Double = 5.0,
        idleAutoSummary: Bool = true,
        idleAutoPodcast: Bool = false
    ) {
        self.concurrentDownloads = concurrentDownloads
        self.storageDirectory = storageDirectory
        self.filenameTemplate = filenameTemplate
        self.limitRate = limitRate
        self.playSoundOnComplete = playSoundOnComplete
        self.clipboardMonitoring = clipboardMonitoring
        self.showOnlyVideo = showOnlyVideo
        self.defaultResolution = defaultResolution
        self.maxRetries = maxRetries
        self.launchAtLogin = launchAtLogin
        self.maxUploadCheck = maxUploadCheck
        self.skipIndexOnFailure = skipIndexOnFailure
        self.openRouterAPIKey = openRouterAPIKey
        self.openRouterModel = openRouterModel
        self.geminiAPIKey = geminiAPIKey
        self.ax4APIKey = ax4APIKey
        self.showMainWindowOnLaunch = showMainWindowOnLaunch
        self.sponsorBlock = sponsorBlock
        self.embedMetadata = embedMetadata
        self.showThumbnailPreview = showThumbnailPreview
        self.ttsEngine = ttsEngine
        self.playerMode = playerMode
        self.showChannelBadge = showChannelBadge
        self.subtitleLanguageOverride = subtitleLanguageOverride
        self.enableWhisperTranscription = enableWhisperTranscription
        self.whisperModelSize = whisperModelSize
        self.showMenuBarNotifications = showMenuBarNotifications
        self.menuBarNotificationDuration = menuBarNotificationDuration
        self.presets = presets
        self.activePresetId = activePresetId
        self.smartMode = smartMode
        self.seekStepSeconds = seekStepSeconds
        self.idleAutoSummary = idleAutoSummary
        self.idleAutoPodcast = idleAutoPodcast
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        concurrentDownloads = try c.decodeIfPresent(Int.self, forKey: .concurrentDownloads) ?? Constants.defaultConcurrentDownloads
        storageDirectory = try c.decodeIfPresent(String.self, forKey: .storageDirectory) ?? Constants.defaultStorageDirectory
        filenameTemplate = try c.decodeIfPresent(String.self, forKey: .filenameTemplate) ?? Constants.defaultFilenameTemplate
        limitRate = try c.decodeIfPresent(Int.self, forKey: .limitRate) ?? 0
        playSoundOnComplete = try c.decodeIfPresent(Bool.self, forKey: .playSoundOnComplete) ?? true
        clipboardMonitoring = try c.decodeIfPresent(Bool.self, forKey: .clipboardMonitoring) ?? true
        showOnlyVideo = try c.decodeIfPresent(Bool.self, forKey: .showOnlyVideo) ?? true
        defaultResolution = try c.decodeIfPresent(Int.self, forKey: .defaultResolution) ?? Constants.defaultResolution
        maxRetries = try c.decodeIfPresent(Int.self, forKey: .maxRetries) ?? Constants.defaultMaxRetries
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        maxUploadCheck = try c.decodeIfPresent(Int.self, forKey: .maxUploadCheck) ?? Constants.defaultMaxUploadCheck
        skipIndexOnFailure = try c.decodeIfPresent(Bool.self, forKey: .skipIndexOnFailure) ?? false
        openRouterAPIKey = try c.decodeIfPresent(String.self, forKey: .openRouterAPIKey) ?? ""
        openRouterModel = try c.decodeIfPresent(String.self, forKey: .openRouterModel) ?? "openrouter/free"
        geminiAPIKey = try c.decodeIfPresent(String.self, forKey: .geminiAPIKey) ?? ""
        ax4APIKey = try c.decodeIfPresent(String.self, forKey: .ax4APIKey) ?? Constants.defaultAX4APIKey
        showMainWindowOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .showMainWindowOnLaunch) ?? true
        sponsorBlock = try c.decodeIfPresent(Bool.self, forKey: .sponsorBlock) ?? true
        embedMetadata = try c.decodeIfPresent(Bool.self, forKey: .embedMetadata) ?? true
        showThumbnailPreview = try c.decodeIfPresent(Bool.self, forKey: .showThumbnailPreview) ?? true
        ttsEngine = try c.decodeIfPresent(TTSEngine.self, forKey: .ttsEngine) ?? .edgeTTS
        playerMode = try c.decodeIfPresent(PlayerMode.self, forKey: .playerMode) ?? .builtIn
        showChannelBadge = try c.decodeIfPresent(Bool.self, forKey: .showChannelBadge) ?? true
        subtitleLanguageOverride = try c.decodeIfPresent(String.self, forKey: .subtitleLanguageOverride) ?? ""
        enableWhisperTranscription = try c.decodeIfPresent(Bool.self, forKey: .enableWhisperTranscription) ?? false
        whisperModelSize = try c.decodeIfPresent(String.self, forKey: .whisperModelSize) ?? "base"
        showMenuBarNotifications = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarNotifications) ?? true
        menuBarNotificationDuration = try c.decodeIfPresent(Int.self, forKey: .menuBarNotificationDuration) ?? 60
        presets = try c.decodeIfPresent([DownloadPreset].self, forKey: .presets) ?? Self.defaultPresets
        activePresetId = try c.decodeIfPresent(UUID.self, forKey: .activePresetId)
        smartMode = try c.decodeIfPresent(Bool.self, forKey: .smartMode) ?? false
        seekStepSeconds = try c.decodeIfPresent(Double.self, forKey: .seekStepSeconds) ?? 5.0
        idleAutoSummary = try c.decodeIfPresent(Bool.self, forKey: .idleAutoSummary) ?? false
        idleAutoPodcast = try c.decodeIfPresent(Bool.self, forKey: .idleAutoPodcast) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(concurrentDownloads, forKey: .concurrentDownloads)
        try c.encode(storageDirectory, forKey: .storageDirectory)
        try c.encode(filenameTemplate, forKey: .filenameTemplate)
        try c.encode(limitRate, forKey: .limitRate)
        try c.encode(playSoundOnComplete, forKey: .playSoundOnComplete)
        try c.encode(clipboardMonitoring, forKey: .clipboardMonitoring)
        try c.encode(showOnlyVideo, forKey: .showOnlyVideo)
        try c.encode(defaultResolution, forKey: .defaultResolution)
        try c.encode(maxRetries, forKey: .maxRetries)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(maxUploadCheck, forKey: .maxUploadCheck)
        try c.encode(skipIndexOnFailure, forKey: .skipIndexOnFailure)
        try c.encode(openRouterAPIKey, forKey: .openRouterAPIKey)
        try c.encode(openRouterModel, forKey: .openRouterModel)
        try c.encode(geminiAPIKey, forKey: .geminiAPIKey)
        try c.encode(ax4APIKey, forKey: .ax4APIKey)
        try c.encode(showMainWindowOnLaunch, forKey: .showMainWindowOnLaunch)
        try c.encode(sponsorBlock, forKey: .sponsorBlock)
        try c.encode(embedMetadata, forKey: .embedMetadata)
        try c.encode(showThumbnailPreview, forKey: .showThumbnailPreview)
        try c.encode(ttsEngine, forKey: .ttsEngine)
        try c.encode(playerMode, forKey: .playerMode)
        try c.encode(showChannelBadge, forKey: .showChannelBadge)
        try c.encode(subtitleLanguageOverride, forKey: .subtitleLanguageOverride)
        try c.encode(enableWhisperTranscription, forKey: .enableWhisperTranscription)
        try c.encode(whisperModelSize, forKey: .whisperModelSize)
        try c.encode(showMenuBarNotifications, forKey: .showMenuBarNotifications)
        try c.encode(menuBarNotificationDuration, forKey: .menuBarNotificationDuration)
        try c.encode(presets, forKey: .presets)
        try c.encodeIfPresent(activePresetId, forKey: .activePresetId)
        try c.encode(smartMode, forKey: .smartMode)
        try c.encode(seekStepSeconds, forKey: .seekStepSeconds)
        try c.encode(idleAutoSummary, forKey: .idleAutoSummary)
        try c.encode(idleAutoPodcast, forKey: .idleAutoPodcast)
    }

    var limitRateArg: String? {
        guard limitRate > 0 else { return nil }
        return "\(limitRate)M"
    }

    struct APIKeys {
        let openRouter: String
        let ax4: String
        let gemini: String
    }

    static func loadAPIKeys() -> APIKeys {
        APIKeys(
            openRouter: UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? "",
            ax4: UserDefaults.standard.string(forKey: "ax4APIKey") ?? Constants.defaultAX4APIKey,
            gemini: UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        )
    }

    static func loadSettings() -> Settings {
        guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
              let data = json.data(using: .utf8),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return settings
    }
}
