import Cocoa
import Combine
import ComposableArchitecture
import UserNotifications

@MainActor
final class ChannelUpdateService {
    private let store: StoreOf<AppReducer>
    private var timer: Timer?
    private var pendingCheck: DispatchWorkItem?
    private var updateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let fetchService = ChannelFetchService()
    #if DEBUG
    private var logManager: DebugLogManager?
    #endif

    init(store: StoreOf<AppReducer>) {
        self.store = store
        observeSettingChanges()
    }

    func start() {
        guard store.state.settings.showChannelBadge else { return }
        startTimer()
    }

    func stop() {
        stopTimer()
        updateTask?.cancel()
        updateTask = nil
    }

    private func observeSettingChanges() {
        store.publisher
            .map(\.settings.showChannelBadge)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] show in
                guard let self else { return }
                if show {
                    self.restartTimer()
                    updateTask = Task { await self.checkForUpdates() }
                } else {
                    stopTimer()
                    updateTask?.cancel()
                    updateTask = nil
                    store.send(.statusBar(.setBadgeCount(0)))
                    store.send(.statusBar(.updateStatusText("")))
                    store.send(.statusBar(.updateStatusDetail("")))
                }
            }
            .store(in: &cancellables)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.checkForUpdates() }
        }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { await self.checkForUpdates() }
        }
        pendingCheck = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: item)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        pendingCheck?.cancel()
        pendingCheck = nil
    }

    private func restartTimer() {
        stopTimer()
        startTimer()
    }

    #if DEBUG
    func setLogManager(_ manager: DebugLogManager) {
        logManager = manager
    }
    #endif

    func checkForUpdates() async {
        guard store.state.settings.showChannelBadge else { return }
        let channels = SubscribedChannel.loadAll()
        guard !channels.isEmpty else {
            #if DEBUG
            logManager?.append("채널 업데이트 체크: 저장된 채널 없음")
            #endif
            return
        }

        #if DEBUG
        logManager?.append("🔄 채널 업데이트 체크 시작 (\(channels.count)개)")
        #endif
        _ = await MainActor.run { [channels] in
            self.store.send(.statusBar(.updateStatusText("신규영상 확인중")))
            self.store.send(.statusBar(.updateStatusDetail("[0/\(channels.count)]")))
        }

        var hasChanges = false
        var newVideosByChannel: [(channelId: String, channelName: String, count: Int, videoIds: [String])] = []

        for (i, channel) in channels.enumerated() {
            if Task.isCancelled { return }
            let detail = "[\(i+1)/\(channels.count)]"
            _ = await MainActor.run { [detail] in
                self.store.send(.statusBar(.updateStatusDetail(detail)))
            }
            #if DEBUG
            logManager?.append("  채널 체크: \(channel.name) (\(i+1)/\(channels.count))")
            #endif

            let lastFetch = ChannelDownloadCache.lastFetchDate(channelId: channel.id)
            let minInterval: TimeInterval = 3600
            guard Date().timeIntervalSince(lastFetch) >= minInterval else {
                #if DEBUG
                logManager?.append("    ⏭ 1시간 이내 fetch 완료, skip")
                #endif
                continue
            }

            guard let result = try? await fetchService.fetchAllVideos(
                channelId: channel.id, handle: channel.handle
            ) else {
                #if DEBUG
                logManager?.append("    ❌ fetch 실패")
                #endif
                continue
            }
            ChannelDownloadCache.markFetchDate(channelId: channel.id)

            let downloadedIDs = ChannelDownloadCache.loadDownloadedIDs(channelName: channel.name)
            let seenIDs = Set(ChannelDownloadCache.loadSeenVideoIds(channelId: channel.id))
            let newVideos = result.videos.filter {
                !downloadedIDs.contains($0.id) && !seenIDs.contains($0.id)
            }
            if !newVideos.isEmpty {
                hasChanges = true
                let videoIds = newVideos.map { $0.id }
                newVideosByChannel.append((channel.id, channel.name, newVideos.count, videoIds))
                ChannelDownloadCache.saveNewVideoIds(channelId: channel.id, videoIds: videoIds)
                #if DEBUG
                logManager?.append("    ✅ 새 영상 \(newVideos.count)개 발견")
                #endif
                if ChannelDownloadCache.isAutoDownloadEnabled(channelId: channel.id) {
                    enqueueAutoDownload(channelId: channel.id, channelName: channel.name, videos: newVideos)
                    #if DEBUG
                    logManager?.append("    📥 자동 다운로드 enqueue \(newVideos.count)개")
                    #endif
                }
            } else {
                #if DEBUG
                logManager?.append("    ➖ 새 영상 없음")
                #endif
            }
        }

        let updatedChannels = ChannelDownloadCache.allChannelsWithNewVideos
        let notifyHasChanges = hasChanges
        let notifyTotal = newVideosByChannel.reduce(0) { $0 + $1.count }
        let notifyDetails = newVideosByChannel.map { ($0.channelName, $0.count) }
        _ = await MainActor.run {
            if notifyHasChanges, self.store.state.settings.showChannelBadge {
                self.store.send(.statusBar(.updateStatusText("업데이트 완료")))
                self.store.send(.statusBar(.updateStatusDetail("새 영상 \(notifyTotal)개")))
                self.showNotification(total: notifyTotal, details: notifyDetails)
                self.store.send(.statusBar(.setBadgeCount(updatedChannels.count)))
            } else {
                self.store.send(.statusBar(.updateStatusText("업데이트 확인")))
                self.store.send(.statusBar(.updateStatusDetail("새 영상 없음")))
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.store.send(.statusBar(.updateStatusText("")))
            self?.store.send(.statusBar(.updateStatusDetail("")))
        }
        #if DEBUG
        logManager?.append("✅ 채널 업데이트 체크 완료 (새 영상 채널 \(updatedChannels.count)개)")
        #endif
    }

    private func enqueueAutoDownload(channelId: String, channelName: String, videos: [ChannelVideoItem]) {
        let preset = ChannelDownloadCache.loadAutoSettings(channelId: channelId)
        guard preset.enabled else { return }
        let resolution = preset.resolution
        let includeSubtitles = preset.includeSubtitles && !preset.audioOnly
        let audioOnly = preset.audioOnly

        var candidates = videos
        if preset.dailyLimit > 0 {
            let todayCount = ChannelDownloadCache.dailyDownloadCount(channelId: channelId)
            let remaining = max(0, preset.dailyLimit - todayCount)
            guard remaining > 0 else {
                #if DEBUG
                logManager?.append("  [AutoDL] \(channelName): 오늘 한도(\(preset.dailyLimit)개) 도달, skip")
                #endif
                return
            }
            candidates = Array(videos.prefix(remaining))
        }

        let items = candidates.map { video -> DownloadItem in
            let format = Format(
                id: "best[height<=\(resolution)]/best",
                label: "\(resolution)p",
                height: resolution,
                ext: "mp4",
                codec: "avc1",
                filesize: nil,
                fps: nil,
                isVideoOnly: false,
                isAudioOnly: false
            )
            let videoInfo = VideoInfo(
                id: video.id,
                title: video.title,
                channel: channelName,
                channelId: channelId,
                duration: 0,
                uploadDate: video.uploadDate ?? "",
                thumbnailURL: video.thumbnailURL,
                webpageURL: "https://youtube.com/watch?v=\(video.id)",
                isPlaylist: false,
                playlistTitle: nil,
                playlistCount: nil
            )
            return DownloadItem(
                videoInfo: videoInfo,
                selectedFormat: format,
                includeSubtitles: includeSubtitles,
                audioOnly: audioOnly,
                isChannelDownload: true,
                channelUploadIndex: 0,
                playlistIndex: video.playlistIndex
            )
        }
        store.send(.downloadQueue(.addItems(items)))
        if preset.dailyLimit > 0 {
            ChannelDownloadCache.incrementDailyDownloadCount(channelId: channelId, by: items.count)
        }
        #if DEBUG
        logManager?.append("  [AutoDL] \(channelName): \(items.count)개 큐에 추가")
        #endif
    }

    private func showNotification(total: Int, details: [(channelName: String, count: Int)]) {
        let content = UNMutableNotificationContent()
        content.title = "새 영상 알림"
        content.body = details.map { "\($0.channelName): \($0.count)개" }.joined(separator: "\n")
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DebugLogManager.shared?.append("[ChannelUpdate] 알림 전송 실패: \(error)")
            }
        }
    }
}
