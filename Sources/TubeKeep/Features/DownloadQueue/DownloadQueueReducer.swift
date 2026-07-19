import Foundation
import AppKit
import ComposableArchitecture

struct ToastMessage: Equatable {
    let id: UUID
    let message: String
    let type: ToastType
}

enum ToastType: Equatable {
    case success
    case error
    case info
}

@Reducer
struct DownloadQueueReducer {
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<DownloadItem> = []
        var maxConcurrent: Int = Constants.defaultConcurrentDownloads
        var maxRetries: Int = Constants.defaultMaxRetries
        var storageDirectory: String = Constants.defaultStorageDirectory
        var filenameTemplate: String = Constants.defaultFilenameTemplate
        var toastMessage: ToastMessage?

        var activeCount: Int {
            items.filter { $0.status == .downloading }.count
        }

        var pendingCount: Int {
            items.filter { $0.status == .pending }.count
        }

        var completedCount: Int {
            items.filter { $0.status == .completed }.count
        }

        var aggregateSpeed: String {
            let speeds = items.compactMap { item -> Double? in
                guard item.status == .downloading,
                      !item.downloadSpeed.isEmpty else { return nil }
                return parseSpeed(item.downloadSpeed)
            }
            let total = speeds.reduce(0, +)
            return formatSpeed(total)
        }

        var aggregateETA: String {
            let remainingTimes = items.compactMap { $0.estimatedRemaining }
            guard !remainingTimes.isEmpty else { return "" }
            let maxRemaining = remainingTimes.max() ?? 0
            if maxRemaining < 60 {
                return String(format: "%.0f초", maxRemaining)
            } else if maxRemaining < 3600 {
                return String(format: "%.0f분", maxRemaining / 60)
            } else {
                return String(format: "%.1f시간", maxRemaining / 3600)
            }
        }

        var hasActiveDownloads: Bool {
            items.contains { $0.status == .downloading }
        }

        var recentlyCompletedCount: Int {
            items.filter { $0.status == .completed }.count
        }

        var failedCount: Int {
            items.filter { $0.status == .failed }.count
        }

        var pausedCount: Int {
            items.filter { $0.status == .paused }.count
        }

        #if DEBUG
        var debugLogs: [String] = []
        #endif
    }

    enum Action: Equatable {
        case loadQueue
        case itemsLoaded([DownloadItem])
        case saveQueue
        case addItem(DownloadItem)
        case addItems([DownloadItem])
        case removeItem(UUID)
        case startDownload(UUID)
        case updateUploadIndex(UUID, Int)
        case pauseDownload(UUID)
        case resumeDownload(UUID)
        case retryDownload(UUID)
        case retryAttempt(UUID)
        case retryAllFailed
        case updateProgress(UUID, Double, String)
        case downloadCompleted(UUID, Bool, String?, String?)
        case revealInFinder(UUID)
        case startAll
        case stopAll
        case clearCompleted
        case clearAll
        case setMaxConcurrent(Int)
        case setMaxRetries(Int)
        case showToast(ToastMessage)
        case dismissToast
        #if DEBUG
        case startTestDownload
        case testProgressTick
        case debugLog(String)
        #endif
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadQueue:
                return .run { send in
                    guard let data = UserDefaults.standard.data(forKey: Constants.downloadQueueKey),
                          let items = try? JSONDecoder().decode([DownloadItem].self, from: data)
                    else { return }
                    let resetItems = items.map { item -> DownloadItem in
                        var item = item
                        if item.status == .downloading || item.status == .paused || item.status == .retrying {
                            item.status = .pending
                            item.downloadStartTime = nil
                            item.downloadSpeed = ""
                        }
                        return item
                    }
                    await send(.itemsLoaded(resetItems))
                }

            case .saveQueue:
                return .run { [items = Array(state.items)] _ in
                    guard let data = try? JSONEncoder().encode(items) else { return }
                    UserDefaults.standard.set(data, forKey: Constants.downloadQueueKey)
                }

            case let .itemsLoaded(items):
                state.items = IdentifiedArray(uniqueElements: items)
                return tryStartNextDownloads(state: &state)

            case let .addItem(item):
                guard !state.items.contains(where: { $0.videoInfo.id == item.videoInfo.id }) else {
                    state.toastMessage = ToastMessage(id: UUID(), message: "이미 목록에 있습니다", type: .info)
                    return .none
                }
                var mutableItem = item
                if let path = mutableItem.checkExistingFile(
                    storageDirectory: state.storageDirectory, template: state.filenameTemplate
                ) {
                    mutableItem.status = .completed
                    mutableItem.outputPath = path
                }
                state.items.append(mutableItem)
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case let .addItems(newItems):
                var skipCount = 0
                for item in newItems {
                    if state.items.contains(where: { $0.videoInfo.id == item.videoInfo.id }) {
                        skipCount += 1
                        continue
                    }
                    var mutableItem = item
                    if let path = mutableItem.checkExistingFile(
                        storageDirectory: state.storageDirectory, template: state.filenameTemplate
                    ) {
                        mutableItem.status = .completed
                        mutableItem.outputPath = path
                    }
                    state.items.append(mutableItem)
                }
                if skipCount > 0 {
                    state.toastMessage = ToastMessage(id: UUID(), message: "중복된 항목이 제외되었습니다", type: .info)
                }
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case let .removeItem(id):
                DownloadManager.shared.cancelDownload(itemId: id)
                state.items.remove(id: id)
                return .send(.saveQueue)

            case let .startDownload(id):
                guard let item = state.items[id: id],
                      item.status == .pending || item.status == .retrying
                else { return .none }
                state.items[id: id]?.status = .downloading
                state.items[id: id]?.downloadStartTime = Date()
                let downloadItem = item
                return .run { send in
                    let settings: Settings = Self.loadSettings()
                    DownloadManager.shared.updateSettings(settings)
                    #if DEBUG
                    await send(.debugLog("[\(timestamp())] ▶️ 다운로드 시작: \(item.videoInfo.title)"))
                    #endif
                    var logHandler: (@Sendable (UUID, String) -> Void)?
                    #if DEBUG
                    logHandler = { id, message in
                        Task { await send(.debugLog("[\(timestamp())] \(message)")) }
                    }
                    #endif
                    DownloadManager.shared.startDownload(
                        item: downloadItem,
                        progressHandler: { id, progress, speed in
                            Task { await send(.updateProgress(id, progress, speed)) }
                        },
                        completionHandler: { id, success, outputPath, error in
                            Task { await send(.downloadCompleted(id, success, outputPath, error)) }
                        },
                        logHandler: logHandler
                    )
                }

            case let .updateUploadIndex(id, index):
                state.items[id: id]?.channelUploadIndex = index
                return .none

            case let .pauseDownload(id):
                guard state.items[id: id]?.status == .downloading
                else { return .none }
                state.items[id: id]?.status = .paused
                state.items[id: id]?.downloadStartTime = nil
                return tryStartNextDownloads(state: &state)

            case let .resumeDownload(id):
                guard state.items[id: id]?.status == .paused
                else { return .none }
                state.items[id: id]?.status = .pending
                state.items[id: id]?.downloadStartTime = nil
                state.items[id: id]?.retryCount = 0
                return tryStartNextDownloads(state: &state)

            case let .retryDownload(id):
                guard state.items[id: id]?.status == .failed || state.items[id: id]?.status == .retrying
                else { return .none }
                state.items[id: id]?.status = .pending
                state.items[id: id]?.progress = 0
                state.items[id: id]?.errorMessage = nil
                state.items[id: id]?.retryCount = 0
                return tryStartNextDownloads(state: &state)

            case let .retryAttempt(id):
                guard state.items[id: id]?.status == .retrying else { return .none }
                state.items[id: id]?.status = .pending
                state.items[id: id]?.downloadStartTime = nil
                return tryStartNextDownloads(state: &state)

            case let .updateProgress(id, progress, speed):
                state.items[id: id]?.progress = progress
                state.items[id: id]?.downloadSpeed = speed
                return .none

            case let .downloadCompleted(id, success, outputPath, error):
                if success {
                    let item = state.items[id: id]
                    state.items[id: id]?.status = .completed
                    state.items[id: id]?.progress = 1.0
                    state.items[id: id]?.downloadSpeed = ""
                    if let outputPath { state.items[id: id]?.outputPath = outputPath }
                    let nextEffect = tryStartNextDownloads(state: &state)
                    let title = state.items[id: id]?.videoInfo.title ?? ""
                    let toast = ToastMessage(
                        id: UUID(),
                        message: "완료: \(title)",
                        type: .success
                    )
                    var effects: [Effect<Action>] = [nextEffect, .send(.showToast(toast))]
                    if let item {
                        effects.append(.run { _ in
                            let videoId = item.videoInfo.id
                            let channelName = item.videoInfo.channel
                            ChannelDownloadCache.addDownloadedID(
                                channelName: channelName,
                                videoId: videoId
                            )
                            let channels = await MainActor.run { SubscribedChannel.loadAll() }
                            if let channel = channels.first(where: { $0.name == channelName }) {
                                ChannelDownloadCache.removeSeenVideoIds(
                                    channelId: channel.id,
                                    videoId: videoId
                                )
                            }
                        })
                    }
                    #if DEBUG
                    effects.append(.send(.debugLog("[\(timestamp())] ✅ 완료: \(item?.videoInfo.title ?? "")")))
                    #endif
                        return .merge(.merge(effects), .send(.saveQueue))
                } else {
                    guard state.items[id: id]?.status == .downloading,
                          let item = state.items[id: id]
                    else { return .none }
                    let retryCount = item.retryCount
                    state.items[id: id]?.errorMessage = error
                    state.items[id: id]?.downloadSpeed = ""

                    if retryCount < state.maxRetries {
                        state.items[id: id]?.retryCount = retryCount + 1
                        state.items[id: id]?.status = .retrying
                        state.items[id: id]?.progress = 0
                        let title = item.videoInfo.title
                        let toast = ToastMessage(
                            id: UUID(),
                            message: "재시도 \(retryCount + 1)/\(state.maxRetries): \(title)",
                            type: .info
                        )
                        var retryEffects: [Effect<Action>] = [
                            .send(.showToast(toast)),
                            .run { [id] send in
                                try await Task.sleep(for: .seconds(3))
                                await send(.retryAttempt(id))
                            }
                        ]
                        #if DEBUG
                        retryEffects.append(.send(.debugLog("[\(timestamp())] ⚠️ 재시도 \(retryCount+1)/\(state.maxRetries): \(item.videoInfo.title)")))
                        #endif
                        return .merge(retryEffects)
                    } else {
                        state.items[id: id]?.status = .failed
                        let nextEffect = tryStartNextDownloads(state: &state)
                        let title = state.items[id: id]?.videoInfo.title ?? ""
                        let toast = ToastMessage(
                            id: UUID(),
                            message: "실패: \(title)\(error.map { " - \($0)" } ?? "")",
                            type: .error
                        )
                        #if DEBUG
                        return .merge(nextEffect, .send(.showToast(toast)), .send(.saveQueue), .send(.debugLog("[\(timestamp())] ❌ 실패: \(title)\(error.map { " - \($0)" } ?? "")")))
                        #else
                        return .merge(nextEffect, .send(.showToast(toast)), .send(.saveQueue))
                        #endif
                    }
                }

            case let .revealInFinder(id):
                guard let item = state.items[id: id],
                      item.status == .completed
                else { return .none }
                return .run { _ in
                    let outputDir = UserDefaults.standard.string(
                        forKey: Constants.settingsSaveKey
                    ).flatMap { try? JSONDecoder().decode(Settings.self, from: Data($0.utf8)) }
                        .map { $0.storageDirectory } ?? Constants.defaultStorageDirectory

                    let fileURL = URL(fileURLWithPath: outputDir)
                        .appendingPathComponent(item.estimatedFilename)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    } else {
                        let dirURL = URL(fileURLWithPath: outputDir)
                        if FileManager.default.fileExists(atPath: dirURL.path) {
                            NSWorkspace.shared.open(dirURL)
                        }
                    }
                }

            case .startAll:
                let active = state.activeCount
                let slots = state.maxConcurrent - active
                guard slots > 0 else { return .none }
                let canStart = state.items
                    .filter { $0.status == .pending || $0.status == .retrying }
                    .prefix(slots)
                    .map { $0.id }
                return .merge(canStart.map { .send(.startDownload($0)) })

            case .stopAll:
                for id in state.items.ids {
                    switch state.items[id: id]?.status {
                    case .downloading:
                        DownloadManager.shared.cancelDownload(itemId: id)
                        state.items[id: id]?.status = .pending
                        state.items[id: id]?.downloadStartTime = nil
                    case .retrying:
                        state.items[id: id]?.status = .pending
                        state.items[id: id]?.downloadStartTime = nil
                        state.items[id: id]?.retryCount = 0
                    default:
                        break
                    }
                }
                return .send(.saveQueue)

            case .retryAllFailed:
                for id in state.items.ids {
                    guard state.items[id: id]?.status == .failed else { continue }
                    state.items[id: id]?.status = .pending
                    state.items[id: id]?.progress = 0
                    state.items[id: id]?.errorMessage = nil
                    state.items[id: id]?.retryCount = 0
                }
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case .clearCompleted:
                state.items.removeAll { $0.status == .completed }
                return .send(.saveQueue)

            case .clearAll:
                state.items.removeAll()
                return .send(.saveQueue)

            case let .setMaxConcurrent(count):
                state.maxConcurrent = max(
                    Constants.minConcurrentDownloads,
                    min(Constants.maxConcurrentDownloads, count)
                )
                return .none

            case let .showToast(toast):
                state.toastMessage = toast
                return .run { send in
                    try await Task.sleep(for: .seconds(3))
                    await send(.dismissToast)
                }
                .cancellable(id: "toastDismiss")

            case .dismissToast:
                state.toastMessage = nil
                return .none

            case let .setMaxRetries(value):
                state.maxRetries = max(0, min(10, value))
                return .none

            #if DEBUG
            case .startTestDownload:
                let testItems = createTestItems()
                for item in testItems {
                    state.items.append(item)
                }
                let nextEffect = tryStartNextDownloads(state: &state)
                return .merge(nextEffect, .run { send in
                    for _ in 0..<20 {
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.testProgressTick)
                    }
                })

            case .testProgressTick:
                let now = Date()
                for id in state.items.ids {
                    guard let item = state.items[id: id],
                          item.status == .downloading,
                          let start = item.downloadStartTime
                    else { continue }
                    let elapsed = now.timeIntervalSince(start)
                    let simulatedDuration: TimeInterval = 4.0
                    let progress = min(1.0, elapsed / simulatedDuration)
                    let speed = progress >= 1.0
                        ? ""
                        : formatSpeed(Double.random(in: 2.0...15.0))
                    state.items[id: id]?.progress = progress
                    state.items[id: id]?.downloadSpeed = speed
                    if progress >= 1.0 {
                        state.items[id: id]?.status = .completed
                    }
                }
                return .none

            case let .debugLog(message):
                state.debugLogs.append(message)
                return .none
            #endif
            }
        }
    }

    private func tryStartNextDownloads(state: inout State) -> Effect<Action> {
        let active = state.activeCount
        let slots = state.maxConcurrent - active

        guard slots > 0 else { return .none }

        let pendingIDs = state.items
            .filter { $0.status == .pending }
            .prefix(slots)
            .map { $0.id }

        return .merge(pendingIDs.map { .send(.startDownload($0)) })
    }

    private static func loadSettings() -> Settings {
        guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
              let data = json.data(using: .utf8),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return settings
    }

    #if DEBUG
    private func createTestItems() -> [DownloadItem] {
        struct TestConfig {
            let title: String
            let channel: String
            let duration: TimeInterval
            let formatLabel: String
            let height: Int
            let subtitles: Bool
            let audioOnly: Bool
        }
        let configs: [TestConfig] = [
            TestConfig(title: "[MV] 아이브(IVE) - 해야 (HEYA)", channel: "starshipTV", duration: 198, formatLabel: "1080p", height: 1080, subtitles: false, audioOnly: false),
            TestConfig(title: "뉴진스(NewJeans) 'How Sweet' Official MV", channel: "NewJeans", duration: 192, formatLabel: "720p", height: 720, subtitles: true, audioOnly: false),
            TestConfig(title: "aespa 에스파 'Supernova' MV", channel: "aespa", duration: 174, formatLabel: "480p", height: 480, subtitles: false, audioOnly: true),
            TestConfig(title: "LE SSERAFIM 'EASY' Official MV", channel: "LE SSERAFIM", duration: 165, formatLabel: "4K", height: 2160, subtitles: true, audioOnly: false),
            TestConfig(title: "BABYMONSTER - 'SHEESH' MV", channel: "BABYMONSTER", duration: 158, formatLabel: "MP3", height: 0, subtitles: false, audioOnly: true),
        ]
        return configs.enumerated().map { i, cfg in
            DownloadItem(
                videoInfo: VideoInfo(
                    id: "test_\(i)",
                    title: cfg.title,
                    channel: cfg.channel,
                    channelId: "test_ch_\(i)",
                    duration: cfg.duration,
                    uploadDate: "20240601",
                    thumbnailURL: "",
                    webpageURL: "https://youtube.com/watch?v=test_\(i)",
                    isPlaylist: false,
                    playlistTitle: nil,
                    playlistCount: nil
                ),
                selectedFormat: Format(
                    id: "test_fmt_\(i)",
                    label: cfg.formatLabel,
                    height: cfg.height,
                    ext: cfg.audioOnly ? "mp3" : "mp4",
                    codec: cfg.audioOnly ? "mp3" : "h264",
                    filesize: Int64.random(in: 10_000_000...200_000_000),
                    fps: cfg.audioOnly ? nil : 30,
                    isVideoOnly: false,
                    isAudioOnly: cfg.audioOnly
                ),
                includeSubtitles: cfg.subtitles,
                audioOnly: cfg.audioOnly,
                channelUploadIndex: i + 1
            )
        }
    }
    #endif
}

private func parseSpeed(_ speed: String) -> Double {
    let cleaned = speed
        .replacingOccurrences(of: "i", with: "")
        .replacingOccurrences(of: "B/s", with: "")
        .trimmingCharacters(in: .whitespaces)

    if cleaned.hasSuffix("G") {
        let val = Double(cleaned.dropLast().trimmingCharacters(in: .whitespaces)) ?? 0
        return val * 1000
    }
    if cleaned.hasSuffix("M") {
        return Double(cleaned.dropLast().trimmingCharacters(in: .whitespaces)) ?? 0
    }
    if cleaned.hasSuffix("K") {
        return (Double(cleaned.dropLast().trimmingCharacters(in: .whitespaces)) ?? 0) / 1000
    }
    return 0
}

private func formatSpeed(_ mbps: Double) -> String {
    if mbps >= 1000 {
        return String(format: "%.1f GB/s", mbps / 1000)
    }
    if mbps >= 1 {
        return String(format: "%.1f MB/s", mbps)
    }
    if mbps > 0 {
        return String(format: "%.0f KB/s", mbps * 1000)
    }
    return ""
}

#if DEBUG
func timestamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: Date())
}
#endif
