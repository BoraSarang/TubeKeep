import Foundation
import ServiceManagement
import ComposableArchitecture

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var home = HomeReducer.State()
        var downloadQueue = DownloadQueueReducer.State()
        var settings = SettingsReducer.State()
        var statusBar = StatusBarReducer.State()
        var library = LibraryReducer.State()
        var profile = ProfileReducer.State()
        var toastNotifications: [ToastNotification] = []
    }

    enum Action: Equatable {
        case home(HomeReducer.Action)
        case downloadQueue(DownloadQueueReducer.Action)
        case settings(SettingsReducer.Action)
        case statusBar(StatusBarReducer.Action)
        case library(LibraryReducer.Action)
        case profile(ProfileReducer.Action)
        case clipboardDetected(String)
        case appDidFinishLaunching
        case discoverAddToQueue(DownloadItem)
        case addToastNotification(ToastMessage)
        case dismissToastNotification(UUID)
    }

    private static func syncStatusBar(_ state: inout State) {
        state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
        state.statusBar.downloadSpeed = state.downloadQueue.aggregateSpeed
        state.statusBar.activeCount = state.downloadQueue.activeCount
        state.statusBar.totalCount = state.downloadQueue.items.count
        state.statusBar.completedCount = state.downloadQueue.completedCount
        state.statusBar.downloadETA = state.downloadQueue.aggregateETA
    }

    /// 큐에 아이템 추가 공통 처리 (중복 검사 + 기존 파일 확인 + append + shouldStart 계산)
    /// - Returns: 중복이면 nil, 성공 시 (itemId, 완료여부, 시작가능여부)
    private static func addItemToQueue(_ item: DownloadItem, into state: inout State) -> (itemId: UUID, isCompleted: Bool, shouldStart: Bool)? {
        guard !state.downloadQueue.items.contains(where: { $0.videoInfo.id == item.videoInfo.id }) else {
            return nil
        }
        var mutableItem = item
        if let path = mutableItem.checkExistingFile(
            storageDirectory: state.settings.storageDirectory,
            template: state.settings.filenameTemplate
        ) {
            mutableItem.status = .completed
            mutableItem.outputPath = path
        }
        state.downloadQueue.items.append(mutableItem)
        state.statusBar.totalCount = state.downloadQueue.items.count
        let shouldStart = state.downloadQueue.activeCount < state.downloadQueue.maxConcurrent
        return (itemId: mutableItem.id, isCompleted: mutableItem.status == .completed, shouldStart: shouldStart)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeReducer()
        }
        Scope(state: \.downloadQueue, action: \.downloadQueue) {
            DownloadQueueReducer()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsReducer()
        }
        Scope(state: \.statusBar, action: \.statusBar) {
            StatusBarReducer()
        }
        Scope(state: \.library, action: \.library) {
            LibraryReducer()
        }
        Scope(state: \.profile, action: \.profile) {
            ProfileReducer()
        }

        Reduce { state, action in
            switch action {
            case let .clipboardDetected(url):
                guard state.home.clipboardMonitoring else { return .none }
                return .send(.home(.autoFetchInfo(url)))

            case .home(.toggleClipboardMonitoring):
                return .send(.settings(.toggleClipboardMonitoring))

            case .appDidFinishLaunching:
                return .merge(
                    .send(.downloadQueue(.loadQueue)),
                    .run { send in
                        let dir = Constants.defaultStorageDirectory
                        if !FileManager.default.fileExists(atPath: dir) {
                            try? FileManager.default.createDirectory(
                                atPath: dir,
                                withIntermediateDirectories: true
                            )
                        }
                    },
                    .run { send in
                        let settings = Settings.loadSettings()
                        await send(.settings(.setConcurrentDownloads(settings.concurrentDownloads)))
                        await send(.settings(.storageDirectorySelected(settings.storageDirectory)))
                        await send(.settings(.setFilenameTemplate(settings.filenameTemplate)))
                        await send(.settings(.setLimitRate(settings.limitRate)))
                        if !settings.playSoundOnComplete {
                            await send(.settings(.togglePlaySound))
                        }
                        if !settings.clipboardMonitoring {
                            await send(.settings(.toggleClipboardMonitoring))
                        }
                        await send(.settings(.setDefaultResolution(settings.defaultResolution)))
                        await send(.settings(.setMaxRetries(settings.maxRetries)))
                        if settings.launchAtLogin {
                            await send(.settings(.setLaunchAtLogin(true)))
                        }
                        await send(.settings(.setMaxUploadCheck(settings.maxUploadCheck)))
                        if settings.skipIndexOnFailure {
                            await send(.settings(.toggleSkipIndexOnFailure))
                        }
                        if !settings.showMainWindowOnLaunch {
                            await send(.settings(.toggleShowMainWindowOnLaunch))
                        }
                        if !settings.sponsorBlock {
                            await send(.settings(.toggleSponsorBlock))
                        }
                        if !settings.embedMetadata {
                            await send(.settings(.toggleEmbedMetadata))
                        }
                        await send(.settings(.setTTSEngine(settings.ttsEngine)))
                        if settings.playerMode != .builtIn {
                            await send(.settings(.setPlayerMode(settings.playerMode)))
                        }
                        if !settings.showChannelBadge {
                            await send(.settings(.toggleShowChannelBadge))
                        }
                        if !settings.subtitleLanguageOverride.isEmpty {
                            await send(.settings(.setSubtitleLanguageOverride(settings.subtitleLanguageOverride)))
                        }
                        if settings.enableWhisperTranscription {
                            await send(.settings(.toggleWhisperTranscription))
                        }
                        if settings.whisperModelSize != "base" {
                            await send(.settings(.setWhisperModelSize(settings.whisperModelSize)))
                        }
                        if !settings.showMenuBarNotifications {
                            await send(.settings(.toggleShowMenuBarNotifications))
                        }
                        if settings.menuBarNotificationDuration != 60 {
                            await send(.settings(.setMenuBarNotificationDuration(settings.menuBarNotificationDuration)))
                        }
                        if settings.smartMode {
                            await send(.settings(.toggleSmartMode))
                        }
                        await send(.settings(.setPresets(settings.presets)))
                        if let activeId = settings.activePresetId {
                            await send(.settings(.setActivePreset(activeId)))
                        }
                    }
                )

            case .home(.infoResponse(_, let formats)):
                let defaultRes = state.settings.defaultResolution
                let defaultFormat = Format.best(forHeight: defaultRes, from: formats)
                state.home.selectedFormatId = defaultFormat?.id

                if state.settings.smartMode,
                   let presetId = state.settings.activePresetId,
                   let preset = state.settings.presets.first(where: { $0.id == presetId }),
                   let info = state.home.videoInfo,
                   let format = defaultFormat {
                    let audioOnly = preset.formatType == .audio
                    let useFormat: Format
                    if audioOnly {
                        useFormat = formats.first(where: { $0.isAudioOnly && $0.isCombined })
                            ?? formats.first(where: { $0.isAudioOnly })
                            ?? format
                    } else {
                        let atOrBelow = formats.filter { !$0.isAudioOnly && $0.height <= preset.resolution }
                        let combined = atOrBelow.filter { $0.isCombined }
                        useFormat = combined.sorted(by: { $0.height > $1.height }).first
                            ?? atOrBelow.sorted(by: { $0.height > $1.height }).first
                            ?? format
                    }
                    let item = DownloadItem(
                        videoInfo: info,
                        selectedFormat: useFormat,
                        includeSubtitles: preset.includeSubtitles,
                        audioOnly: audioOnly,
                        channelUploadIndex: 0
                    )
                    return .send(.home(.addToQueueResponse(item)))
                }

                return .none

            case .home(.addToQueueResponse(let item)):
                guard let (itemId, isCompleted, shouldStart) = Self.addItemToQueue(item, into: &state) else {
                    state.home.urlString = ""
                    state.home.videoInfo = nil
                    state.home.availableFormats = []
                    state.home.selectedFormatId = nil
                    state.home.lastAutoFetchedURL = ""
                    return .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 목록에 있습니다", type: .info))))
                }
                state.home.urlString = ""
                state.home.videoInfo = nil
                state.home.availableFormats = []
                state.home.selectedFormatId = nil
                state.home.lastAutoFetchedURL = ""

                if isCompleted {
                    return .concatenate(
                        .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 다운로드된 파일입니다", type: .info)))),
                        .run { _ in
                            let hi = DownloadHistoryItem(
                                id: 0,
                                videoId: item.videoInfo.id,
                                title: item.videoInfo.title,
                                channelName: item.videoInfo.channel,
                                url: item.videoInfo.webpageURL,
                                formatLabel: item.selectedFormat.label,
                                resolution: item.selectedFormat.height,
                                fileSize: (item.outputPath.map { try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? Int64 } ?? nil) ?? nil,
                                filePath: item.outputPath,
                                downloadedAt: Date(),
                                status: "completed"
                            )
                            DatabaseManager.shared.saveDownloadHistory(hi)
                            NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                        }
                    )
                }

                // index=0이면 먼저 fetch 후 startDownload (race condition 방지)
                if item.channelUploadIndex == 0, item.isChannelDownload {
                    let capturedItem = item
                    return .run { send in
                        let service = UploadOrderService()
                        let index = (try? await service.fetchUploadIndex(
                            channelId: capturedItem.videoInfo.channelId,
                            targetVideoId: capturedItem.videoInfo.id
                        )) ?? 0
                        await send(.downloadQueue(.updateUploadIndex(itemId, index)))
                        if shouldStart {
                            await send(.downloadQueue(.startDownload(itemId)))
                        }
                    }
                }

                if shouldStart {
                    return .send(.downloadQueue(.startDownload(itemId)))
                }
                return .none

            case .home(.playlistSelection(.presented(.confirmSelection))):
                guard let playlistState = state.home.playlistSelection else {
                    return .none
                }
                let selectedVideos = playlistState.sortedVideos.filter {
                    playlistState.selectedIds.contains($0.id)
                }

                var items: [DownloadItem] = []
                for (index, video) in selectedVideos.enumerated() {
                    guard let format = state.home.selectedFormat else { continue }
                    let item = DownloadItem(
                        videoInfo: video,
                        selectedFormat: format,
                        includeSubtitles: state.home.includeSubtitles,
                        audioOnly: state.home.audioOnly,
                        channelUploadIndex: index + 1,
                        playlistIndex: index + 1
                    )
                    // Skip queue duplicate
                    if state.downloadQueue.items.contains(where: { $0.videoInfo.id == video.id }) { continue }
                    var mutableItem = item
                    if let path = mutableItem.checkExistingFile(
                        storageDirectory: state.settings.storageDirectory,
                        template: state.settings.filenameTemplate
                    ) {
                        mutableItem.status = .completed
                        mutableItem.outputPath = path
                    }
                    items.append(mutableItem)
                }

                state.downloadQueue.items.append(contentsOf: items)
                state.statusBar.totalCount = state.downloadQueue.items.count
                let slotsLeft = state.downloadQueue.maxConcurrent - state.downloadQueue.activeCount
                let toStart = items.filter { $0.status != .completed }.prefix(max(0, slotsLeft))
                state.home.playlistSelection = nil
                state.home.videoInfo = nil
                state.home.availableFormats = []
                return .merge(toStart.map { .send(.downloadQueue(.startDownload($0.id))) })

            case .home(.playlistSelection(.presented(.cancel))):
                state.home.playlistSelection = nil
                return .none

            case .downloadQueue(.updateProgress(_, _, _)):
                Self.syncStatusBar(&state)
                return .none

            case let .downloadQueue(.downloadCompleted(id, success, outputPath, _)):
                let completed = state.downloadQueue.recentlyCompletedCount
                if completed > 0 {
                    state.statusBar.badgeCount = completed
                }
                Self.syncStatusBar(&state)
                let historyItem = state.downloadQueue.items[id: id].map { item in
                    DownloadHistoryItem(
                        id: 0,
                        videoId: item.videoInfo.id,
                        title: item.videoInfo.title,
                        channelName: item.videoInfo.channel,
                        url: item.videoInfo.webpageURL,
                        formatLabel: item.selectedFormat.label,
                        resolution: item.selectedFormat.height,
                        fileSize: (outputPath.map { try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? Int64 } ?? nil) ?? nil,
                        filePath: outputPath,
                        downloadedAt: Date(),
                        status: success ? "completed" : "failed"
                    )
                }
                if success {
                    let libraryItem = state.downloadQueue.items[id: id].map { item in
                        LibraryItem(
                            id: item.videoInfo.id,
                            title: item.videoInfo.title,
                            channelId: item.videoInfo.channelId,
                            channelName: item.videoInfo.channel,
                            thumbnailURL: item.videoInfo.thumbnailURL,
                            filePath: outputPath ?? item.estimatedFilename,
                            downloadDate: Date(),
                            uploadDate: LibraryItem.parseUploadDate(item.videoInfo.uploadDate),
                            duration: item.videoInfo.duration > 0 ? Int(item.videoInfo.duration) : nil,
                            channelUploadIndex: item.channelUploadIndex > 0 ? item.channelUploadIndex : nil
                        )
                    }
                    return .run { send in
                        if let hi = historyItem {
                            DatabaseManager.shared.saveDownloadHistory(hi)
                            NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                        }
                        if let li = libraryItem {
                            let liId = li.id
                            let liTitle = li.title
                            let liChannel = li.channelName
                            await LibraryCacheService.shared.addItem(li)
                            await send(.library(.tagItem(videoId: liId, title: liTitle, channel: liChannel)))
                        }
                        await send(.library(.loadFromDisk))
                        await send(.library(.calculateDiskUsage))
                    }
                }
                return .run { _ in
                    if let hi = historyItem {
                        DatabaseManager.shared.saveDownloadHistory(hi)
                        NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                    }
                }

                case .downloadQueue(.removeItem), .downloadQueue(.retryAllFailed):
                Self.syncStatusBar(&state)
                return .none

            case .downloadQueue(.startDownload), .downloadQueue(.pauseDownload), .downloadQueue(.resumeDownload):
                Self.syncStatusBar(&state)
                return .none

            case .downloadQueue(.clearCompleted), .downloadQueue(.clearAll):
                state.statusBar.completedCount = 0
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.badgeCount = 0
                return .none

            case .settings(.setConcurrentDownloads(let value)):
                state.downloadQueue.maxConcurrent = value
                return .none

            case .settings(.storageDirectorySelected(let path)):
                state.settings.storageDirectory = path
                state.downloadQueue.storageDirectory = path
                return .none

            case .settings(.setFilenameTemplate(let template)):
                state.settings.filenameTemplate = template
                state.downloadQueue.filenameTemplate = template
                return .none

            case .settings(.setMaxRetries(let value)):
                state.downloadQueue.maxRetries = value
                return .none

            case .library(.itemsLoaded):
                return .none

            case let .discoverAddToQueue(item):
                guard let (itemId, isCompleted, shouldStart) = Self.addItemToQueue(item, into: &state) else {
                    return .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 목록에 있습니다", type: .info))))
                }

                if isCompleted {
                    return .merge(
                        .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 다운로드된 파일입니다", type: .info)))),
                        .run { _ in
                            let hi = DownloadHistoryItem(
                                id: 0,
                                videoId: item.videoInfo.id,
                                title: item.videoInfo.title,
                                channelName: item.videoInfo.channel,
                                url: item.videoInfo.webpageURL,
                                formatLabel: item.selectedFormat.label,
                                resolution: item.selectedFormat.height,
                                fileSize: (item.outputPath.map { try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? Int64 } ?? nil) ?? nil,
                                filePath: item.outputPath,
                                downloadedAt: Date(),
                                status: "completed"
                            )
                            DatabaseManager.shared.saveDownloadHistory(hi)
                            NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                        }
                    )
                }

                if shouldStart {
                    return .send(.downloadQueue(.startDownload(itemId)))
                }
                return .none

            case .library(.showSummary):
                return .none

            case .library(.resummarize):
                return .none

            case .library(.summaryResult):
                return .none

            case .library(.summaryFailed):
                return .none

            case .library(.tagItem):
                return .none

            case .library(.itemTagged):
                return .none

            case .addToastNotification(let toast):
                let notif = ToastNotification(
                    id: toast.id,
                    message: toast.message,
                    type: toast.type,
                    timestamp: Date()
                )
                state.toastNotifications.append(notif)
                if state.toastNotifications.count > 5 {
                    state.toastNotifications.removeFirst()
                }
                return .none

            case .dismissToastNotification(let id):
                state.toastNotifications.removeAll { $0.id == id }
                return .none

            case .downloadQueue(.showToast(let toast)):
                return .send(.addToastNotification(toast))

            case .library(.showSubtitleToastToast(let toast)):
                return .send(.addToastNotification(toast))

            default:
                return .none
            }
        }
    }
}
