import Foundation
import AppKit
import ComposableArchitecture
import os
import WidgetKit

enum QueueStore {
    static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.borasarang.tubekeep")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("downloadQueue.json")
    }

    static func loadItems() -> [DownloadItem]? {
        if let data = try? Data(contentsOf: fileURL),
           let items = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            return items
        }
        if let data = UserDefaults.standard.data(forKey: Constants.downloadQueueKey),
           let items = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            saveItems(items)
            return items
        }
        return nil
    }

    static func saveItems(_ items: [DownloadItem]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            if let data = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(data, forKey: Constants.downloadQueueKey)
            }
        }
    }
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
        var lastQueueSaveDate: Date?

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

        var aggregateProgress: Double {
            let active = items.filter { $0.status == .downloading }
            guard !active.isEmpty else { return 0 }
            return active.reduce(0) { $0 + max(0, min(1, $1.progress)) } / Double(active.count)
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

    }

    enum Action: Equatable {
        case loadQueue
        case itemsLoaded([DownloadItem])
        case saveQueue
        case setItems([DownloadItem])
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
        case debugLog(String)
        case showToast(ToastMessage)
        case dismissToast
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadQueue:
                return .run { send in
                    guard let items = QueueStore.loadItems() else {
                        #if DEBUG
                        DebugLogManager.shared?.append("[Download] 큐 로드 실패 (파일/UserDefaults 없음)")
                        #endif
                        return
                    }
                    let resetItems = items.map { item -> DownloadItem in
                        var item = item
                        if item.status == .downloading || item.status == .paused || item.status == .retrying {
                            item.status = .pending
                            item.downloadStartTime = nil
                            item.downloadSpeed = ""
                        }
                        return item
                    }
                    #if DEBUG
                    DebugLogManager.shared?.append("[Download] 큐 로드: \(resetItems.count)개 (진행/일시중지를 대기로 리셋)")
                    #endif
                    await send(.itemsLoaded(resetItems))
                }

            case .saveQueue:
                return .run { [items = Array(state.items)] _ in
                    QueueStore.saveItems(items)
                }

            case let .itemsLoaded(items):
                let loadedSettings = Settings.loadSettings()
                state.storageDirectory = loadedSettings.storageDirectory
                state.filenameTemplate = loadedSettings.filenameTemplate
                var mapped = items
                var completedNew: [DownloadItem] = []
                var invalidated: [String] = []
                for idx in mapped.indices {
                    switch mapped[idx].status {
                    case .pending:
                        if let path = mapped[idx].checkExistingFile(
                            storageDirectory: state.storageDirectory,
                            template: state.filenameTemplate
                        ) {
                            mapped[idx].status = .completed
                            mapped[idx].outputPath = path
                            mapped[idx].progress = 1.0
                            completedNew.append(mapped[idx])
                            #if DEBUG
                            DebugLogManager.shared?.append("[Download] 이미 다운로드된 파일 감지 → 완료 처리: \(mapped[idx].videoInfo.id)")
                            #endif
                        }
                    case .completed:
                        // 과거 버그(.part/.webp를 완료로 오인)로 남은 유령 완료를 재검증한다.
                        if let path = mapped[idx].checkExistingFile(
                            storageDirectory: state.storageDirectory,
                            template: state.filenameTemplate
                        ) {
                            mapped[idx].outputPath = path
                            completedNew.append(mapped[idx])
                        } else {
                            invalidated.append(mapped[idx].videoInfo.id)
                            mapped[idx].status = .pending
                            mapped[idx].outputPath = nil
                            mapped[idx].progress = 0
                            mapped[idx].downloadSpeed = ""
                            #if DEBUG
                            DebugLogManager.shared?.append("[Download] 유령 완료 재검증 → 대기로 되돌림: \(mapped[idx].videoInfo.id)")
                            #endif
                        }
                    default:
                        break
                    }
                }
                state.items = IdentifiedArray(uniqueElements: mapped)
                var effects: [Effect<Action>] = [tryStartNextDownloads(state: &state), .send(.saveQueue)]
                // 유령 완료(실미디어 없음)로 되돌린 항목은 히스토리의 잘못된 completed 기록도 정리한다.
                if !invalidated.isEmpty {
                    effects.append(.run { _ in
                        for videoId in invalidated {
                            let history = DatabaseManager.shared.loadDownloadHistory()
                            if let rec = history.first(where: { $0.videoId == videoId && $0.status == "completed" }) {
                                DatabaseManager.shared.deleteDownloadHistory(id: rec.id)
                                DebugLogManager.shared?.append("[Download] 히스토리 유령 완료 제거: \(videoId)")
                            }
                        }
                        NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                    })
                }
                // 이전 크래시/강제 종료로 완료 처리됐지만 보관함·히스토리에 누락된 항목을 보정 등록한다.
                for item in completedNew {
                    effects.append(.run { send in
                        let videoId = item.videoInfo.id
                        guard let outputPath = item.outputPath else { return }
                        let alreadyInHistory = DatabaseManager.shared.loadDownloadHistory()
                            .contains { $0.videoId == videoId }
                        if !alreadyInHistory {
                            let hi = DownloadHistoryItem(
                                id: 0,
                                videoId: videoId,
                                title: item.videoInfo.title,
                                channelName: item.videoInfo.channel,
                                url: item.videoInfo.webpageURL,
                                formatLabel: item.selectedFormat.label,
                                resolution: item.selectedFormat.height,
                                fileSize: (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64) ?? nil,
                                filePath: outputPath,
                                downloadedAt: Date(),
                                status: "completed"
                            )
                            DatabaseManager.shared.saveDownloadHistory(hi)
                            NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                        }
                        ChannelDownloadCache.addDownloadedID(channelName: item.videoInfo.channel, videoId: videoId)
                        await MainActor.run {
                            guard LibraryCacheService.shared.findItem(id: videoId) == nil else { return }
                            let li = LibraryItem(
                                id: videoId,
                                title: item.videoInfo.title,
                                channelId: item.videoInfo.channelId,
                                channelName: item.videoInfo.channel,
                                thumbnailURL: item.videoInfo.thumbnailURL,
                                filePath: outputPath,
                                downloadDate: Date(),
                                uploadDate: LibraryItem.parseUploadDate(item.videoInfo.uploadDate),
                                duration: item.videoInfo.duration > 0 ? Int(item.videoInfo.duration) : nil,
                                channelUploadIndex: item.channelUploadIndex > 0 ? item.channelUploadIndex : nil
                            )
                            LibraryCacheService.shared.addItem(li)
                        }
                    })
                }
                return .merge(effects)

            case let .setItems(items):
                state.items = IdentifiedArray(uniqueElements: items)
                return .send(.saveQueue)

            case let .addItem(item):
                let loadedSettings = Settings.loadSettings()
                state.storageDirectory = loadedSettings.storageDirectory
                state.filenameTemplate = loadedSettings.filenameTemplate
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
                let loadedSettings = Settings.loadSettings()
                state.storageDirectory = loadedSettings.storageDirectory
                state.filenameTemplate = loadedSettings.filenameTemplate
                var skipCount = 0
                let historyIDs = Set(
                    DatabaseManager.shared.loadDownloadHistory()
                        .filter { $0.status == "completed" }
                        .compactMap { $0.videoId }
                )
                for item in newItems {
                    if state.items.contains(where: { $0.videoInfo.id == item.videoInfo.id }) {
                        skipCount += 1
                        continue
                    }
                    if historyIDs.contains(item.videoInfo.id) {
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
                let storageDir = state.storageDirectory
                let item = state.items[id: id]
                DownloadManager.shared.cancelDownload(itemId: id)
                if let item {
                    cleanupTempFiles(for: item, storageDirectory: storageDir)
                }
                state.items.remove(id: id)
                return .send(.saveQueue)

            case let .startDownload(id):
                guard let item = state.items[id: id],
                      item.status == .pending || item.status == .retrying
                else { return .none }
                state.items[id: id]?.status = .downloading
                state.items[id: id]?.downloadStartTime = Date()
                let downloadItem = item
                return .merge(
                    .send(.saveQueue),
                    .run { send in
                        let settings: Settings = Settings.loadSettings()
                        DownloadManager.shared.updateSettings(settings)
                        #if DEBUG
                        await send(.debugLog("▶️ 시작: \(item.videoInfo.title)"))
                        #endif
                        let stream = AsyncStream<Action> { continuation in
                            var logHandler: (@Sendable (UUID, String) -> Void)?
                            #if DEBUG
                            logHandler = { id, message in
                                continuation.yield(.debugLog(message))
                            }
                            #endif
                            DownloadManager.shared.startDownload(
                                item: downloadItem,
                                progressHandler: { id, progress, speed in
                                    continuation.yield(.updateProgress(id, progress, speed))
                                },
                                completionHandler: { id, success, outputPath, error in
                                    continuation.yield(.downloadCompleted(id, success, outputPath, error))
                                    continuation.finish()
                                },
                                logHandler: logHandler
                            )
                        }
                        for await action in stream {
                            await send(action)
                        }
                    }
                )

            case let .updateUploadIndex(id, index):
                state.items[id: id]?.channelUploadIndex = index
                return .none

            case let .pauseDownload(id):
                guard state.items[id: id]?.status == .downloading
                else { return .none }
                state.items[id: id]?.status = .paused
                state.items[id: id]?.downloadStartTime = nil
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case let .resumeDownload(id):
                guard state.items[id: id]?.status == .paused
                else { return .none }
                state.items[id: id]?.status = .pending
                state.items[id: id]?.downloadStartTime = nil
                state.items[id: id]?.retryCount = 0
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case let .retryDownload(id):
                guard state.items[id: id]?.status == .failed || state.items[id: id]?.status == .retrying
                else { return .none }
                state.items[id: id]?.status = .pending
                state.items[id: id]?.progress = 0
                state.items[id: id]?.errorMessage = nil
                state.items[id: id]?.retryCount = 0
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case let .retryAttempt(id):
                guard state.items[id: id]?.status == .retrying else { return .none }
                state.items[id: id]?.status = .pending
                state.items[id: id]?.downloadStartTime = nil
                return .merge(tryStartNextDownloads(state: &state), .send(.saveQueue))

            case let .updateProgress(id, progress, speed):
                state.items[id: id]?.progress = progress
                state.items[id: id]?.downloadSpeed = speed
                state.saveWidgetSnapshot()
                if let last = state.lastQueueSaveDate,
                   Date().timeIntervalSince(last) < 15 {
                    return .none
                }
                state.lastQueueSaveDate = Date()
                return .send(.saveQueue)

            case let .downloadCompleted(id, success, outputPath, error):
                if success {
                    let item = state.items[id: id]
                    state.items[id: id]?.status = .completed
                    state.items[id: id]?.progress = 1.0
                    state.items[id: id]?.downloadSpeed = ""
                    if let outputPath { state.items[id: id]?.outputPath = outputPath }
                    if let item {
                        cleanupTempFiles(for: item, storageDirectory: state.storageDirectory)
                    }
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
                            await MainActor.run {
                                let channels = SubscribedChannel.loadAll()
                                if let channel = channels.first(where: { $0.name == channelName }) {
                                    ChannelDownloadCache.removeSeenVideoIds(
                                        channelId: channel.id,
                                        videoId: videoId
                                    )
                                }
                            }
                        })
                    }
                    #if DEBUG
                    effects.append(.send(.debugLog("✅ 완료: \(item?.videoInfo.title ?? "")")))
                    #endif
                    state.saveWidgetSnapshot()
                    effects.append(.run { _ in
                        WidgetCenter.shared.reloadTimelines(ofKind: "DownloadStatus")
                    })
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
                        retryEffects.append(.send(.debugLog("⚠️ 재시도 \(retryCount+1)/\(state.maxRetries): \(item.videoInfo.title)")))
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
                        return .merge(nextEffect, .send(.showToast(toast)), .send(.saveQueue), .send(.debugLog("❌ 실패: \(title)\(error.map { " - \($0)" } ?? "")")))
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
                    let outputDir = Settings.loadSettings().storageDirectory

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

            case let .debugLog(message):
                #if DEBUG
                DebugLogManager.shared?.append("[Download] \(message)")
                #endif
                return .none
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

private func cleanupTempFiles(for item: DownloadItem, storageDirectory: String) {
    let folder = Constants.sanitizeFolderName(item.videoInfo.channel)
    let channelDir = "\(storageDirectory)/\(folder)"
    let videoId = item.videoInfo.id
    let fm = FileManager.default

    guard let files = try? fm.contentsOfDirectory(atPath: channelDir) else { return }
    // 살아있는 실제 미디어 파일이 있어야만 그 videoId의 temp(.part/.webp 등)를 정리한다.
    // 미디어가 없으면 강제 종료로 남은 .part를 보존해 재시작 시 재개할 수 있게 한다.
    let hasMedia = files.contains {
        let path = "\(channelDir)/\($0)"
        return DownloadItem.isRealMediaFile(at: path)
    }
    guard hasMedia else { return }
    for file in files {
        let path = "\(channelDir)/\(file)"
        guard file.contains(videoId) else { continue }
        let ext = (file as NSString).pathExtension.lowercased()
        if ext == "part" || ext == "webp" || ext == "jpg" || ext == "png" {
            try? fm.removeItem(atPath: path)
        }
    }

    // yt-dlp output path temp file
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("tubekeep_output_\(item.id.uuidString).txt")
    try? fm.removeItem(at: tempFile)
}

extension DownloadQueueReducer.State {
    func saveWidgetSnapshot() {
        let active = items.filter { $0.status == .downloading }.prefix(3).map {
            WidgetSnapshot.Active(title: $0.videoInfo.title, progress: $0.progress, speed: $0.downloadSpeed)
        }
        let waiting = items.filter { $0.status == .pending || $0.status == .retrying }.count
        let recentCompleted = items.filter { $0.status == .completed }
            .suffix(5)
            .map { WidgetSnapshot.Recent(title: $0.videoInfo.title, completedAt: $0.downloadStartTime ?? Date()) }
        WidgetSnapshot(active: Array(active), waiting: waiting, recentCompleted: recentCompleted).save()
    }
}
