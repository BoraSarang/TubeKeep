import Foundation
import AppKit
import ServiceManagement
import ComposableArchitecture

@Reducer
struct SettingsReducer {
    @ObservableState
    struct State: Equatable {
        var isExpanded: Bool = false
        var concurrentDownloads: Int = Constants.defaultConcurrentDownloads
        var outputDirectory: String = Constants.defaultOutputDirectory
        var filenameTemplate: String = Constants.defaultFilenameTemplate
        var limitRate: Int = 0
        var playSoundOnComplete: Bool = true
        var clipboardMonitoring: Bool = true
        var defaultResolution: Int = Constants.defaultResolution
        var maxRetries: Int = Constants.defaultMaxRetries
        var launchAtLogin: Bool = false
        var maxUploadCheck: Int = Constants.defaultMaxUploadCheck
        var skipIndexOnFailure: Bool = false

        var settings: Settings {
            Settings(
                concurrentDownloads: concurrentDownloads,
                outputDirectory: outputDirectory,
                filenameTemplate: filenameTemplate,
                limitRate: limitRate,
                playSoundOnComplete: playSoundOnComplete,
                clipboardMonitoring: clipboardMonitoring,
                defaultResolution: defaultResolution,
                maxRetries: maxRetries,
                launchAtLogin: launchAtLogin,
                maxUploadCheck: maxUploadCheck,
                skipIndexOnFailure: skipIndexOnFailure
            )
        }
    }

    enum Action: Equatable {
        case toggleExpanded
        case setConcurrentDownloads(Int)
        case selectOutputDirectory
        case outputDirectorySelected(String)
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
        case saveSettings
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleExpanded:
                state.isExpanded.toggle()
                return .none

            case let .setConcurrentDownloads(value):
                state.concurrentDownloads = max(
                    Constants.minConcurrentDownloads,
                    min(Constants.maxConcurrentDownloads, value)
                )
                return .send(.saveSettings)

            case .selectOutputDirectory:
                return .run { send in
                    let path = await MainActor.run { () -> String? in
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.message = "다운로드 폴더 선택"
                        panel.directoryURL = URL(fileURLWithPath: Constants.defaultOutputDirectory)
                        guard panel.runModal() == .OK, let url = panel.url
                        else { return nil }
                        return url.path
                    }
                    if let path = path {
                        await send(.outputDirectorySelected(path))
                    }
                }

            case let .outputDirectorySelected(path):
                state.outputDirectory = path
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
