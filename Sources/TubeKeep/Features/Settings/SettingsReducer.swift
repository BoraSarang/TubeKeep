import Foundation
import AppKit
import ServiceManagement
import ComposableArchitecture

private struct WhisperDownloadCancelID: Hashable {}

struct DerivedDataReport: Equatable {
    var summary = 0
    var chapters = 0
    var mindmap = 0
    var tags = 0
    var subtitles = 0
    var transcripts = 0
    var qna = 0
    var podcastFiles = 0
    var podcastBytes: Int64 = 0

    var message: String {
        var parts: [String] = []
        func add(_ count: Int, _ label: String) {
            if count > 0 { parts.append("\(label) \(count)개") }
        }
        add(summary, "요약")
        add(chapters, "챕터")
        add(mindmap, "마인드맵")
        add(tags, "태그")
        add(subtitles, "자막")
        add(transcripts, "대본")
        add(qna, "자주 묻는 질문")
        if podcastFiles > 0 {
            let mb = Float(podcastBytes) / 1_048_576.0
            parts.append("팟캐스트 \(podcastFiles)개(\(String(format: "%.1f", mb))MB)")
        }
        return parts.isEmpty
            ? "삭제할 AI 파생 데이터가 없었습니다."
            : "다음 항목이 삭제되었습니다.\n" + parts.joined(separator: " · ")
    }
}

/// 모델 탭의 클라우드 공급자 구분 — 목록 조회/선택 저장 대상
enum CloudProviderKind: String, CaseIterable, Equatable {
    case ollama
    case gemini
    case nvidia
    case openRouter

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .gemini: return "Gemini"
        case .nvidia: return "NVIDIA NIM"
        case .openRouter: return "OpenRouter"
        }
    }
}

@Reducer
struct SettingsReducer {
    @Dependency(\.continuousClock) private var clock

    @ObservableState
    struct State: Equatable {
        var selectedTab: SettingsTab = .downloads
        var clearReport: DerivedDataReport?
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
        var showLibraryOnLaunch: Bool = true
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
        var idleSubtitleMode: String = "auto"
        var idleSubtitleSort: String = "recent"
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

        // MARK: - 클라우드 공급자 (NVIDIA NIM + 모델 선택)
        var nvidiaAPIKey: String {
            get { UserDefaults.standard.string(forKey: "nvidiaAPIKey") ?? "" }
            set { UserDefaults.standard.set(newValue, forKey: "nvidiaAPIKey") }
        }

        // 모델 탭 — 클라우드 모델 목록 + 토글 사용 설정 (TCA 감지 위해 stored)
        var ollamaEnabledModels: Set<String> = []
        var geminiEnabledModels: Set<String> = []
        var nvidiaEnabledModels: Set<String> = []
        var openRouterEnabledModels: Set<String> = []
        var geminiModels: [CloudModelInfo] = []
        var nvidiaModels: [CloudModelInfo] = []
        var openRouterModels: [CloudModelInfo] = []
        var geminiModelsLoading = false
        var nvidiaModelsLoading = false
        var openRouterModelsLoading = false
        var cloudModelError: String?
        var modelSearchText = ""
        var openRouterFreeOnly = true

        // MARK: - 로컬 Ollama
        // TCA 변경 감지를 위해 stored property 사용 — 저장은 reducer 액션에서 수행
        var ollamaEnabled: Bool = UserDefaults.standard.object(forKey: "ollamaEnabled") as? Bool ?? true
        var ollamaServerRunning: Bool = false
        var ollamaModels: [String] = []
        var ollamaPullProgress: Double?
        var ollamaInstallingModel: String?
        var ollamaPullError: String?

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
                showLibraryOnLaunch: showLibraryOnLaunch,
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
                idleAutoPodcast: idleAutoPodcast,
                idleSubtitleMode: idleSubtitleMode,
                idleSubtitleSort: idleSubtitleSort
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
        case toggleShowLibraryOnLaunch
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
        case setIdleSubtitleMode(String)
        case setIdleSubtitleSort(String)
        case toggleShowMenuBarNotifications
        case setMenuBarNotificationDuration(Int)
        case setOpenRouterAPIKey(String)
        case toggleOllamaEnabled
        case refreshOllamaStatus
        case ollamaStatusChecked(running: Bool, models: [String])
        case installOllamaModel(String)
        case ollamaPullProgressUpdated(fraction: Double, status: String)
        case ollamaPullCompleted(String)
        case ollamaPullFailed(String, String)
        case deleteOllamaModel(String)
        case setNVIDIAAPIKey(String)
        case loadEnabledModels
        case toggleCloudModel(CloudProviderKind, String)
        case fetchCloudModels(CloudProviderKind)
        case cloudModelsLoaded(CloudProviderKind, [CloudModelInfo])
        case cloudModelsFailed(CloudProviderKind, String)
        case setModelSearchText(String)
        case toggleOpenRouterFreeOnly
        case setOpenRouterModel(String)
        case setGeminiAPIKey(String)
        case clearDerivedAIData
        case clearDerivedAIDataReported(DerivedDataReport?)
        case dismissClearReport
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

            case .toggleShowLibraryOnLaunch:
                state.showLibraryOnLaunch.toggle()
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

            case let .setIdleSubtitleMode(mode):
                state.idleSubtitleMode = mode
                return .send(.saveSettings)

            case let .setIdleSubtitleSort(sort):
                state.idleSubtitleSort = sort
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

            case .toggleOllamaEnabled:
                state.ollamaEnabled.toggle()
                UserDefaults.standard.set(state.ollamaEnabled, forKey: "ollamaEnabled")
                OllamaService.invalidateServerCache()
                return .none

            case .loadEnabledModels:
                CloudModelPrefs.migrateIfNeeded()
                state.ollamaEnabledModels = Set(CloudModelPrefs.enabled(.ollama))
                state.geminiEnabledModels = Set(CloudModelPrefs.enabled(.gemini))
                state.nvidiaEnabledModels = Set(CloudModelPrefs.enabled(.nvidia))
                state.openRouterEnabledModels = Set(CloudModelPrefs.enabled(.openRouter))
                return .none

            case let .toggleCloudModel(kind, id):
                CloudModelPrefs.toggle(kind, id)
                switch kind {
                case .ollama: state.ollamaEnabledModels = Set(CloudModelPrefs.enabled(kind))
                case .gemini: state.geminiEnabledModels = Set(CloudModelPrefs.enabled(kind))
                case .nvidia: state.nvidiaEnabledModels = Set(CloudModelPrefs.enabled(kind))
                case .openRouter: state.openRouterEnabledModels = Set(CloudModelPrefs.enabled(kind))
                }
                #if DEBUG
                DebugLogManager.shared?.append("[Settings] \(kind.displayName) 모델 사용 토글 — \(id) → \(CloudModelPrefs.isEnabled(kind, id) ? "사용" : "해제")")
                #endif
                return .none

            case .refreshOllamaStatus:
                OllamaService.invalidateServerCache()
                return .run { send in
                    let running = await OllamaService.isServerRunning()
                    let models = running ? await OllamaService.listModels() : []
                    await send(.ollamaStatusChecked(running: running, models: models))
                }

            case let .ollamaStatusChecked(running, models):
                state.ollamaServerRunning = running
                state.ollamaModels = models
                return .none

            case let .installOllamaModel(name):
                guard state.ollamaPullProgress == nil else { return .none }
                state.ollamaInstallingModel = name
                state.ollamaPullProgress = 0
                state.ollamaPullError = nil
                return .run { send in
                    do {
                        try await OllamaService.pullModel(name) { fraction, status in
                            Task { await send(.ollamaPullProgressUpdated(fraction: fraction, status: status)) }
                        }
                        await send(.ollamaPullCompleted(name))
                    } catch {
                        await send(.ollamaPullFailed(name, error.localizedDescription))
                    }
                }

            case let .ollamaPullProgressUpdated(fraction, _):
                state.ollamaPullProgress = fraction
                return .none

            case let .ollamaPullCompleted(name):
                state.ollamaPullProgress = nil
                state.ollamaInstallingModel = nil
                OllamaService.invalidateServerCache()
                #if DEBUG
                DebugLogManager.shared?.append("[Settings] Ollama 모델 설치 완료 — \(name)")
                #endif
                return .run { send in
                    let running = await OllamaService.isServerRunning()
                    let models = running ? await OllamaService.listModels() : []
                    await send(.ollamaStatusChecked(running: running, models: models))
                }

            case let .ollamaPullFailed(_, message):
                state.ollamaPullProgress = nil
                state.ollamaInstallingModel = nil
                state.ollamaPullError = message
                return .none

            case let .deleteOllamaModel(name):
                return .run { send in
                    try? await OllamaService.deleteModel(name)
                    OllamaService.invalidateServerCache()
                    #if DEBUG
                    DebugLogManager.shared?.append("[Settings] Ollama 모델 삭제 완료 — \(name)")
                    #endif
                    let running = await OllamaService.isServerRunning()
                    let models = running ? await OllamaService.listModels() : []
                    await send(.ollamaStatusChecked(running: running, models: models))
                }

            case let .setNVIDIAAPIKey(key):
                state.nvidiaAPIKey = key
                return .none

            case let .fetchCloudModels(kind):
                #if DEBUG
                DebugLogManager.shared?.append("[Settings] \(kind.displayName) 모델 목록 조회 요청")
                #endif
                switch kind {
                case .ollama:
                    return .none
                case .gemini:
                    guard !state.geminiAPIKey.isEmpty else {
                        state.cloudModelError = "Gemini API 키를 먼저 입력해 주세요"
                        return .none
                    }
                    state.geminiModelsLoading = true
                    state.cloudModelError = nil
                    let apiKey = state.geminiAPIKey
                    return .run { send in
                        do {
                            let models = try await GeminiService.listModels(apiKey: apiKey)
                            await send(.cloudModelsLoaded(.gemini, models))
                        } catch {
                            await send(.cloudModelsFailed(.gemini, error.localizedDescription))
                        }
                    }
                case .nvidia:
                    guard !state.nvidiaAPIKey.isEmpty else {
                        state.cloudModelError = "NVIDIA API 키를 먼저 입력해 주세요"
                        return .none
                    }
                    state.nvidiaModelsLoading = true
                    state.cloudModelError = nil
                    let apiKey = state.nvidiaAPIKey
                    return .run { send in
                        do {
                            let models = try await NVIDIAService.listModels(apiKey: apiKey)
                            await send(.cloudModelsLoaded(.nvidia, models))
                        } catch {
                            await send(.cloudModelsFailed(.nvidia, error.localizedDescription))
                        }
                    }
                case .openRouter:
                    state.openRouterModelsLoading = true
                    state.cloudModelError = nil
                    return .run { send in
                        do {
                            let models = try await OpenRouterService.listModels()
                            await send(.cloudModelsLoaded(.openRouter, models))
                        } catch {
                            await send(.cloudModelsFailed(.openRouter, error.localizedDescription))
                        }
                    }
                }

            case let .cloudModelsLoaded(kind, models):
                #if DEBUG
                DebugLogManager.shared?.append("[Settings] ✅ \(kind.displayName) 모델 목록 갱신 — \(models.count)개")
                #endif
                switch kind {
                case .ollama: break
                case .gemini:
                    state.geminiModels = models
                    state.geminiModelsLoading = false
                case .nvidia:
                    state.nvidiaModels = models
                    state.nvidiaModelsLoading = false
                case .openRouter:
                    state.openRouterModels = models.sorted {
                        ($0.isFree == $1.isFree) ? $0.id < $1.id : $0.isFree && !$1.isFree
                    }
                    state.openRouterModelsLoading = false
                }
                return .none

            case let .cloudModelsFailed(kind, message):
                #if DEBUG
                DebugLogManager.shared?.append("[Settings] ❌ \(kind.displayName) 모델 목록 실패 — E-MAC-NET-1004 \(message)")
                #endif
                state.cloudModelError = message
                switch kind {
                case .ollama: break
                case .gemini: state.geminiModelsLoading = false
                case .nvidia: state.nvidiaModelsLoading = false
                case .openRouter: state.openRouterModelsLoading = false
                }
                return .none

            case let .setModelSearchText(text):
                state.modelSearchText = text
                return .none

            case .toggleOpenRouterFreeOnly:
                state.openRouterFreeOnly.toggle()
                return .none

            case .clearDerivedAIData:
                return .run { send in
                    await MainActor.run {
                        let before = DatabaseManager.shared.snapshotDerivedDataCounts()
                        let podBefore = PodcastService.shared.podcastFilesInfo()
                        DatabaseManager.shared.clearDerivedAIData()
                        PodcastService.shared.clearAllPodcastFiles()
                        LibraryCacheService.shared.clearDerivedAI()
                        NotificationCenter.default.post(name: Constants.libraryDataDidChangeNotification, object: nil)
                        #if DEBUG
                        DebugLogManager.shared?.append("[Settings] AI 파생 데이터 초기화 완료")
                        #endif
                        let report = DerivedDataReport(
                            summary: before.summary,
                            chapters: before.chapters,
                            mindmap: before.mindmap,
                            tags: before.tags,
                            subtitles: before.subtitles,
                            transcripts: before.transcripts,
                            qna: before.qna,
                            podcastFiles: podBefore.files,
                            podcastBytes: podBefore.bytes
                        )
                        send(.clearDerivedAIDataReported(report))
                    }
                }

            case let .clearDerivedAIDataReported(report):
                state.clearReport = report
                return .none

            case .dismissClearReport:
                state.clearReport = nil
                return .none

            case .saveSettings:
                let settings = state.settings
                return .run { _ in
                    try await clock.sleep(for: .milliseconds(500))
                    if let data = try? JSONEncoder().encode(settings),
                       let json = String(data: data, encoding: .utf8) {
                        UserDefaults.standard.set(json, forKey: Constants.settingsSaveKey)
                    }
                }
                .cancellable(id: "saveSettings", cancelInFlight: true)
            }
        }
    }
}
