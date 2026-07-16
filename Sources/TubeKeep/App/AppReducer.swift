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
    }

    enum Action: Equatable {
        case home(HomeReducer.Action)
        case downloadQueue(DownloadQueueReducer.Action)
        case settings(SettingsReducer.Action)
        case statusBar(StatusBarReducer.Action)
        case library(LibraryReducer.Action)
        case clipboardDetected(String)
        case appDidFinishLaunching
        case discoverAddToQueue(DownloadItem)
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
                        if let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
                           let data = json.data(using: .utf8),
                           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
                            await send(.settings(.setConcurrentDownloads(settings.concurrentDownloads)))
                            await send(.settings(.storageDirectorySelected(settings.storageDirectory)))
                            await send(.settings(.setFilenameTemplate(settings.filenameTemplate)))
                            await send(.settings(.setLimitRate(settings.limitRate)))
                            if settings.playSoundOnComplete {
                                await send(.settings(.togglePlaySound))
                            }
                            if settings.clipboardMonitoring {
                                // already true by default
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
                        }
                    }
                )

            case .home(.infoResponse(_, let formats)):
                let defaultRes = state.settings.defaultResolution
                let defaultFormat = Format.best(forHeight: defaultRes, from: formats)
                state.home.selectedFormatId = defaultFormat?.id
                return .none

            case .home(.addToQueueResponse(let item)):
                guard !state.downloadQueue.items.contains(where: { $0.videoInfo.id == item.videoInfo.id }) else {
                    state.home.urlString = ""
                    state.home.videoInfo = nil
                    state.home.availableFormats = []
                    state.home.selectedFormatId = nil
                    state.home.lastAutoFetchedURL = ""
                    return .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 목록에 있습니다", type: .info))))
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
                let itemId = mutableItem.id
                state.home.urlString = ""
                state.home.videoInfo = nil
                state.home.availableFormats = []
                state.home.selectedFormatId = nil
                state.home.lastAutoFetchedURL = ""

                if mutableItem.status == .completed {
                    return .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 다운로드된 파일입니다", type: .info))))
                }

                // index=0이면 먼저 fetch 후 startDownload (race condition 방지)
                if mutableItem.channelUploadIndex == 0, mutableItem.isChannelDownload {
                    let capturedItem = mutableItem
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
                state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
                state.statusBar.downloadSpeed = state.downloadQueue.aggregateSpeed
                state.statusBar.activeCount = state.downloadQueue.activeCount
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.completedCount = state.downloadQueue.completedCount
                state.statusBar.downloadETA = state.downloadQueue.aggregateETA
                return .none

            case let .downloadQueue(.downloadCompleted(id, success, _)):
                let completed = state.downloadQueue.recentlyCompletedCount
                if completed > 0 {
                    state.statusBar.badgeCount = completed
                }
                state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
                state.statusBar.downloadSpeed = state.downloadQueue.aggregateSpeed
                state.statusBar.activeCount = state.downloadQueue.activeCount
                state.statusBar.completedCount = state.downloadQueue.completedCount
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.downloadETA = state.downloadQueue.aggregateETA
                if success {
                    let libraryItem = state.downloadQueue.items[id: id].map { item in
                        LibraryItem(
                            id: item.videoInfo.id,
                            title: item.videoInfo.title,
                            channelId: item.videoInfo.channelId,
                            channelName: item.videoInfo.channel,
                            thumbnailURL: item.videoInfo.thumbnailURL,
                            filePath: item.estimatedFilename,
                            downloadDate: Date(),
                            uploadDate: LibraryItem.parseUploadDate(item.videoInfo.uploadDate),
                            duration: item.videoInfo.duration > 0 ? Int(item.videoInfo.duration) : nil,
                            channelUploadIndex: item.channelUploadIndex > 0 ? item.channelUploadIndex : nil
                        )
                    }
                    return .run { send in
                        if let li = libraryItem {
                            await LibraryCacheService.shared.addItem(li)
                            await send(.library(.tagItem(videoId: li.id, title: li.title, channel: li.channelName)))
                        }
                        await send(.library(.loadFromDisk))
                        await send(.library(.calculateDiskUsage))
                    }
                }
                return .none

                case .downloadQueue(.removeItem), .downloadQueue(.retryAllFailed):
                state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
                state.statusBar.downloadSpeed = state.downloadQueue.aggregateSpeed
                state.statusBar.activeCount = state.downloadQueue.activeCount
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.completedCount = state.downloadQueue.completedCount
                state.statusBar.downloadETA = state.downloadQueue.aggregateETA
                return .none

            case .downloadQueue(.startDownload), .downloadQueue(.pauseDownload), .downloadQueue(.resumeDownload):
                state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
                state.statusBar.downloadSpeed = state.downloadQueue.aggregateSpeed
                state.statusBar.activeCount = state.downloadQueue.activeCount
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.completedCount = state.downloadQueue.completedCount
                state.statusBar.downloadETA = state.downloadQueue.aggregateETA
                return .none

            case .downloadQueue(.clearCompleted), .downloadQueue(.clearAll):
                state.statusBar.completedCount = 0
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.badgeCount = 0
                return .none

            #if DEBUG
            case .downloadQueue(.startTestDownload):
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.activeCount = state.downloadQueue.activeCount
                state.statusBar.completedCount = 0
                state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
                return .none

            case .downloadQueue(.testProgressTick):
                state.statusBar.hasActiveDownloads = state.downloadQueue.hasActiveDownloads
                state.statusBar.downloadSpeed = state.downloadQueue.aggregateSpeed
                state.statusBar.activeCount = state.downloadQueue.activeCount
                state.statusBar.totalCount = state.downloadQueue.items.count
                state.statusBar.completedCount = state.downloadQueue.completedCount
                state.statusBar.downloadETA = state.downloadQueue.aggregateETA
                return .none
            #endif

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
                guard !state.downloadQueue.items.contains(where: { $0.videoInfo.id == item.videoInfo.id }) else {
                    return .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 목록에 있습니다", type: .info))))
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
                let itemId = mutableItem.id

                if mutableItem.status == .completed {
                    return .send(.downloadQueue(.showToast(ToastMessage(id: UUID(), message: "이미 다운로드된 파일입니다", type: .info))))
                }

                if shouldStart {
                    return .send(.downloadQueue(.startDownload(itemId)))
                }
                return .none

            case .library(.showSummary):
                return .none

            case .library(.summaryResult):
                return .none

            case .library(.summaryFailed):
                return .none

            case .library(.tagItem):
                return .none

            case .library(.itemTagged):
                return .none

            default:
                return .none
            }
        }
    }
}
