import Foundation
import AppKit
import ServiceManagement
import ComposableArchitecture

private struct WhisperDownloadCancelID: Hashable {}

@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var selectedTab: SettingsTab = .downloads
        var concurrentDownloads: Int = Constants.defaultConcurrentDownloads
        var storageDirectory: String = Constants.defaultStorageDirectory
        var filenameTemplate: String = Constants.defaultFilenameTemplate
        var limitRate: Int = 0
        var playSoundOnComplete: Bool = true
        var clipboardMonitoring: Bool = true
        var defaultResolution: Int = Constants.defaultResolution
        var maxRetries: Int = Constants.defaultMaxRetries
        var launchAtLogin: Bool = false
        var maxUploadCheck: Int = Constants.defaultMaxUploadCheck
        var skipIndexOnFailure: Bool = false
        var showMainWindowOnLaunch: Bool = true
        var showOnlyVideo: Bool = true
        var showThumbnailPreview: Bool = true
        var sponsorBlock: Bool = true
        var embedMetadata: Bool = true
        var ttsEngine: TTSEngine = .edgeTTS
        var playerMode: PlayerMode = .builtIn
        var showChannelBadge: Bool = true
        var subtitleLanguageOverride: String = ""
        var enableWhisperTranscription: Bool = false
        var whisperModelSize: String = "base"
        var whisperModelStatus: WhisperModelStatus = .unknown
        var whisperModelProgress: Double = 0
        var whisperModelError: String?
        var showMenuBarNotifications: Bool = true
        var menuBarNotificationDuration: Int = 60
        var presets: [DownloadPreset] = Settings.defaultPresets
        var activePresetId: UUID?
        var smartMode: Bool = false
        var seekStepSeconds: Double = 5.0
        var idleAutoSummary: Bool = true
        var idleAutoPodcast: Bool = false
        var openRouterAPIKey: String {
            get { UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? "" }
            set { UserDefaults.standard.set(newValue, forKey: "openRouterAPIKey") }
        }
        var openRouterModel: String {
            get { UserDefaults.standard.string(forKey: "openRouterModel") ?? "openrouter/free" }
            set { UserDefaults.standard.set(newValue, forKey: "openRouterModel") }
        }
        var geminiAPIKey: String {
            get { UserDefaults.standard.string(forKey: "geminiAPIKey") ?? "" }
            set { UserDefaults.standard.set(newValue, forKey: "geminiAPIKey") }
        }
        var ax4APIKey: String {
            get { UserDefaults.standard.string(forKey: "ax4APIKey") ?? Constants.defaultAX4APIKey }
            set { UserDefaults.standard.set(newValue, forKey: "ax4APIKey") }
        }

        var settings: Settings {
            Settings(
                concurrentDownloads: concurrentDownloads,
                storageDirectory: storageDirectory,
                filenameTemplate: filenameTemplate,
                limitRate: limitRate,
                playSoundOnComplete: playSoundOnComplete,
                clipboardMonitoring: clipboardMonitoring,
                showOnlyVideo: showOnlyVideo,
                defaultResolution: defaultResolution,
                maxRetries: maxRetries,
                launchAtLogin: launchAtLogin,
                maxUploadCheck: maxUploadCheck,
                skipIndexOnFailure: skipIndexOnFailure,
                openRouterAPIKey: openRouterAPIKey,
                showMainWindowOnLaunch: showMainWindowOnLaunch,
                sponsorBlock: sponsorBlock,
                embedMetadata: embedMetadata,
                showThumbnailPreview: showThumbnailPreview,
                ttsEngine: ttsEngine,
                playerMode: playerMode,
                showChannelBadge: showChannelBadge,
                subtitleLanguageOverride: subtitleLanguageOverride,
                enableWhisperTranscription: enableWhisperTranscription,
                whisperModelSize: whisperModelSize,
                showMenuBarNotifications: showMenuBarNotifications,
                menuBarNotificationDuration: menuBarNotificationDuration,
                presets: presets,
                activePresetId: activePresetId,
                smartMode: smartMode,
                seekStepSeconds: seekStepSeconds,
                idleAutoSummary: idleAutoSummary,
                idleAutoPodcast: idleAutoPodcast
            )
        }
    }

    enum Action: Equatable {
        case setSelectedTab(SettingsTab)
        case setConcurrentDownloads(Int)
        case selectStorageDirectory
        case storageDirectorySelected(String)
        case setFilenameTemplate(String)
        case setLimitRate(Int)
        case togglePlaySound
        case toggleClipboardMonitoring
        case setDefaultResolution(Int)
        case setMaxRetries(Int)
        case toggleLaunchAtLogin
        case setLaunchAtLogin(Bool)
        case setMaxUploadCheck(Int)
        case toggleSkipIndexOnFailure
        case toggleShowMainWindowOnLaunch
        case toggleShowOnlyVideo
        case toggleShowThumbnailPreview
        case toggleSponsorBlock
        case toggleEmbedMetadata
        case setTTSEngine(TTSEngine)
        case setPlayerMode(PlayerMode)
        case toggleShowChannelBadge
        case setSubtitleLanguageOverride(String)
        case toggleWhisperTranscription
        case setWhisperModelSize(String)
        case checkWhisperModelStatus
        case downloadWhisperModel
        case cancelWhisperModelDownload
        case whisperModelStatusUpdated(WhisperModelStatus)
        case whisperModelProgressUpdated(Double)
        case whisperModelDownloadCompleted
        case whisperModelDownloadFailed(String)
        case addPreset(DownloadPreset)
        case updatePreset(DownloadPreset)
        case deletePreset(UUID)
        case setActivePreset(UUID?)
        case setPresets([DownloadPreset])
        case toggleSmartMode
        case setSeekStepSeconds(Double)
        case toggleIdleAutoSummary
        case toggleIdleAutoPodcast
        case toggleShowMenuBarNotifications
        case setMenuBarNotificationDuration(Int)
        case setOpenRouterAPIKey(String)
        case setOpenRouterModel(String)
        case setGeminiAPIKey(String)
        case setAX4APIKey(String)
        case saveSettings
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setSelectedTab(tab):
                state.selectedTab = tab
                return .none

            case let .setConcurrentDownloads(value):
                state.concurrentDownloads = max(
                    Constants.minConcurrentDownloads,
                    min(Constants.maxConcurrentDownloads, value)
                )
                return .send(.saveSettings)

            case .selectStorageDirectory:
                return .run { send in
                    let path = await MainActor.run { () -> String? in
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.message = "저장 폴더 선택"
                        panel.directoryURL = URL(fileURLWithPath: Constants.defaultStorageDirectory)
                        guard panel.runModal() == .OK, let url = panel.url
                        else { return nil }
                        BookmarkManager.refreshBookmark(for: url)
                        return url.path
                    }
                    if let path = path {
                        await send(.storageDirectorySelected(path))
                    }
                }

            case let .storageDirectorySelected(path):
                state.storageDirectory = path
                return .send(.saveSettings)

            case let .setFilenameTemplate(template):
                state.filenameTemplate = template
                return .send(.saveSettings)

            case let .setLimitRate(value):
                state.limitRate = max(0, value)
                return .send(.saveSettings)

            case .togglePlaySound:
                state.playSoundOnComplete.toggle()
                return .send(.saveSettings)

            case .toggleClipboardMonitoring:
                state.clipboardMonitoring.toggle()
                return .send(.saveSettings)

            case let .setDefaultResolution(resolution):
                state.defaultResolution = resolution
                return .send(.saveSettings)

            case let .setMaxRetries(value):
                state.maxRetries = max(0, min(10, value))
                return .send(.saveSettings)

            case .toggleLaunchAtLogin:
                state.launchAtLogin.toggle()
                return .run { [enabled = state.launchAtLogin] _ in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        DebugLogManager.shared?.append("[Settings] Failed to \(enabled ? "register" : "unregister") login item: \(error)")
                    }
                }

            case let .setLaunchAtLogin(enabled):
                state.launchAtLogin = enabled
                return .run { _ in
                    guard enabled else { return }
                    do {
                        try SMAppService.mainApp.register()
                    } catch {
                        DebugLogManager.shared?.append("[Settings] Failed to register login item: \(error)")
                    }
                }

            case let .setMaxUploadCheck(value):
                state.maxUploadCheck = max(100, min(10000, value))
                return .send(.saveSettings)

            case .toggleSkipIndexOnFailure:
                state.skipIndexOnFailure.toggle()
                return .send(.saveSettings)

            case .toggleShowMainWindowOnLaunch:
                state.showMainWindowOnLaunch.toggle()
                return .send(.saveSettings)

            case .toggleShowOnlyVideo:
                state.showOnlyVideo.toggle()
                return .send(.saveSettings)

            case .toggleShowThumbnailPreview:
                state.showThumbnailPreview.toggle()
                return .send(.saveSettings)

            case .toggleSponsorBlock:
                state.sponsorBlock.toggle()
                return .send(.saveSettings)

            case .toggleEmbedMetadata:
                state.embedMetadata.toggle()
                return .send(.saveSettings)

            case let .setTTSEngine(engine):
                state.ttsEngine = engine
                return .send(.saveSettings)

            case let .setPlayerMode(mode):
                state.playerMode = mode
                return .send(.saveSettings)

            case .toggleShowChannelBadge:
                state.showChannelBadge.toggle()
                return .send(.saveSettings)

            case let .setSubtitleLanguageOverride(value):
                state.subtitleLanguageOverride = value
                return .send(.saveSettings)

            case .toggleWhisperTranscription:
                state.enableWhisperTranscription.toggle()
                return .send(.saveSettings)

            case let .setWhisperModelSize(value):
                state.whisperModelSize = value
                return .merge(.send(.saveSettings), .send(.checkWhisperModelStatus))

            case .checkWhisperModelStatus:
                let size = state.whisperModelSize
                let installed = WhisperService.shared.isModelDownloaded(size)
                state.whisperModelStatus = installed ? .installed : .notInstalled
                state.whisperModelProgress = 0
                state.whisperModelError = nil
                return .none

            case .downloadWhisperModel:
                let size = state.whisperModelSize
                let force = state.whisperModelStatus == .installed
                state.whisperModelStatus = .downloading
                state.whisperModelProgress = 0
                state.whisperModelError = nil
                return .run { send in
                    let service = WhisperService.shared
                    try await service.downloadModel(
                        size: size,
                        progressHandler: { _ in },
                        numericProgress: { progress in
                            Task { @MainActor in
                                send(.whisperModelProgressUpdated(progress))
                            }
                        },
                        force: force
                    )
                    await send(.whisperModelDownloadCompleted)
                } catch: { error, send in
                    if error is CancellationError {
                        await send(.cancelWhisperModelDownload)
                    } else {
                        await send(.whisperModelDownloadFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: WhisperDownloadCancelID())

            case .cancelWhisperModelDownload:
                state.whisperModelStatus = .notInstalled
                state.whisperModelProgress = 0
                return .cancel(id: WhisperDownloadCancelID())

            case let .whisperModelStatusUpdated(status):
                state.whisperModelStatus = status
                return .none

            case let .whisperModelProgressUpdated(progress):
                state.whisperModelProgress = progress
                return .none

            case .whisperModelDownloadCompleted:
                state.whisperModelStatus = .installed
                state.whisperModelProgress = 1.0
                return .none

            case let .whisperModelDownloadFailed(error):
                state.whisperModelStatus = .error
                state.whisperModelError = error
                state.whisperModelProgress = 0
                return .none

            case let .addPreset(preset):
                state.presets.append(preset)
                return .send(.saveSettings)

            case let .updatePreset(preset):
                if let idx = state.presets.firstIndex(where: { $0.id == preset.id }) {
                    state.presets[idx] = preset
                }
                return .send(.saveSettings)

            case let .deletePreset(id):
                state.presets.removeAll { $0.id == id }
                if state.activePresetId == id {
                    state.activePresetId = nil
                }
                return .send(.saveSettings)

            case let .setActivePreset(id):
                state.activePresetId = id
                return .send(.saveSettings)

            case let .setPresets(presets):
                state.presets = presets
                return .send(.saveSettings)

            case .toggleShowMenuBarNotifications:
                state.showMenuBarNotifications.toggle()
                return .send(.saveSettings)

            case let .setMenuBarNotificationDuration(value):
                state.menuBarNotificationDuration = max(10, min(600, value))
                return .send(.saveSettings)

            case .toggleSmartMode:
                state.smartMode.toggle()
                return .send(.saveSettings)

            case let .setSeekStepSeconds(value):
                state.seekStepSeconds = max(1, min(60, value))
                return .send(.saveSettings)

            case .toggleIdleAutoSummary:
                state.idleAutoSummary.toggle()
                return .send(.saveSettings)

            case .toggleIdleAutoPodcast:
                state.idleAutoPodcast.toggle()
                return .send(.saveSettings)

            case let .setOpenRouterAPIKey(key):
                state.openRouterAPIKey = key
                return .none

            case let .setOpenRouterModel(model):
                state.openRouterModel = model
                return .none

            case let .setGeminiAPIKey(key):
                state.geminiAPIKey = key
                return .none

            case let .setAX4APIKey(key):
                state.ax4APIKey = key
                return .none

            case .saveSettings:
                return .run { [settings = state.settings] _ in
                    if let data = try? JSONEncoder().encode(settings),
                       let json = String(data: data, encoding: .utf8) {
                        UserDefaults.standard.set(json, forKey: Constants.settingsSaveKey)
                    }
                }
            }
        }
    }
}
