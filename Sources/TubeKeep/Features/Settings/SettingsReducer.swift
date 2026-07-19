import Foundation
import AppKit
import ServiceManagement
import ComposableArchitecture

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
        var sponsorBlock: Bool = true
        var embedMetadata: Bool = true
        var ttsEngine: TTSEngine = .apple
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
                defaultResolution: defaultResolution,
                maxRetries: maxRetries,
                launchAtLogin: launchAtLogin,
                maxUploadCheck: maxUploadCheck,
                skipIndexOnFailure: skipIndexOnFailure,
                openRouterAPIKey: openRouterAPIKey,
                showMainWindowOnLaunch: showMainWindowOnLaunch,
                sponsorBlock: sponsorBlock,
                embedMetadata: embedMetadata,
                ttsEngine: ttsEngine
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
        case toggleSponsorBlock
        case toggleEmbedMetadata
        case setTTSEngine(TTSEngine)
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
                        print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
                    }
                }

            case let .setLaunchAtLogin(enabled):
                state.launchAtLogin = enabled
                return .run { _ in
                    guard enabled else { return }
                    do {
                        try SMAppService.mainApp.register()
                    } catch {
                        print("Failed to register login item: \(error)")
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

            case .toggleSponsorBlock:
                state.sponsorBlock.toggle()
                return .send(.saveSettings)

            case .toggleEmbedMetadata:
                state.embedMetadata.toggle()
                return .send(.saveSettings)

            case let .setTTSEngine(engine):
                state.ttsEngine = engine
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
