import Cocoa
import Combine
import ComposableArchitecture
import UserNotifications

@MainActor
final class ChannelUpdateService {
    private let store: StoreOf<AppReducer>
    private var timer: Timer?
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
    }

    private func observeSettingChanges() {
        store.publisher
            .map(\.settings.showChannelBadge)
            .removeDuplicates()
            .sink { [weak self] show in
                guard let self else { return }
                if show {
                    self.restartTimer()
                    Task { await self.checkForUpdates() }
                } else {
                    self.stopTimer()
                    self.store.send(.statusBar(.setBadgeCount(0)))
                    self.store.send(.statusBar(.updateStatusText("")))
                    self.store.send(.statusBar(.updateStatusDetail("")))
                }
            }
            .store(in: &cancellables)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.checkForUpdates() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            Task { await self.checkForUpdates() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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

    private func showNotification(total: Int, details: [(channelName: String, count: Int)]) {
        let content = UNMutableNotificationContent()
        content.title = "새 영상 알림"
        content.body = details.map { "\($0.channelName): \($0.count)개" }.joined(separator: "\n")
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 전송 실패: \(error)")
            }
        }
    }
}
