import SwiftUI
import ComposableArchitecture

struct ChannelDownloaderView: View {
    let store: StoreOf<AppReducer>
    let initialChannelId: String?
    let pendingChannelData: [String: Any]?

    init(store: StoreOf<AppReducer>, initialChannelId: String? = nil, pendingChannelData: [String: Any]? = nil) {
        self.store = store
        self.initialChannelId = initialChannelId
        self.pendingChannelData = pendingChannelData
    }

    @State private var channels: [SubscribedChannel] = []
    @State private var selectedChannel: SubscribedChannel?
    @State private var channelVideos: [ChannelVideoItem] = []
    @State private var isLoadingVideos = false
    @State private var isAddingChannel = false
    @State private var isShowingAddDialog = false
    @State private var addChannelURL = ""
    @State private var errorMessage: String?
    @State private var isPinned = false
    @State private var fetchTask: Task<Void, Never>?

    // Channel video loading progress
    @State private var channelLoadCount: Int = 0
    @State private var channelLoadTotal: Int = 0
    @State private var channelLoadStart: Date?
    @State private var loadGeneration = 0
    @State private var channelLoadEstimate: TimeInterval?
    @State private var channelLoadProbeDone = false

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                ChannelListView(
                    channels: channels,
                    selectedChannel: $selectedChannel,
                    onSelect: { channel in
                        selectedChannel = channel
                        DebugLogManager.shared?.append("[Channel] ▶️ 채널 선택: \(channel.name)")
                        let currentNew = ChannelDownloadCache.loadNewVideoIds(channelId: channel.id)
                        if !currentNew.isEmpty {
                            ChannelDownloadCache.saveSeenVideoIds(channelId: channel.id, videoIds: currentNew)
                            ChannelDownloadCache.clearNewVideoIds(channelId: channel.id)
                        }
                        let remaining = ChannelDownloadCache.allChannelsWithNewVideos.count
                        store.send(.statusBar(.setBadgeCount(remaining)))
                        loadVideos(for: channel)
                    },
                    onAdd: { isShowingAddDialog = true },
                    onDelete: deleteChannel,
                    onMoveChannels: { from, to in
                        guard from.first != nil else { return }
                        channels.move(fromOffsets: from, toOffset: to)
                        SubscribedChannel.saveAll(channels)
                    }
                )
                .frame(minWidth: 180, maxWidth: 180)

                ChannelContentView(
                    store: store,
                    channel: selectedChannel,
                    videos: channelVideos,
                    isLoading: isLoadingVideos,
                    loadCount: channelLoadCount,
                    loadTotal: channelLoadTotal,
                    loadStart: channelLoadStart,
                    loadEstimate: channelLoadEstimate,
                    loadProbeDone: channelLoadProbeDone,
                    onRefresh: {
                        if let channel = selectedChannel {
                            loadVideos(for: channel, force: true)
                            refreshChannelInfo(for: channel)
                        }
                    },
                    onDropURL: { url in
                        addChannelURL = url
                        addChannel()
                    },
                    onAddChannel: { isShowingAddDialog = true }
                )
                .frame(minWidth: 480)
            }

            if isAddingChannel {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("채널 정보를 불러오는 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.textBackgroundColor))
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 11))
                    Spacer()
                    Button("✕") { errorMessage = nil }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.textBackgroundColor))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onDisappear {
            fetchTask?.cancel()
            fetchTask = nil
        }
        .onAppear {
            DebugLogManager.shared?.append("[Channel] 🟢 onAppear triggered")
            channels = SubscribedChannel.loadAll()
            DebugLogManager.shared?.append("[Channel] ℹ️ 저장된 채널 \(channels.count)개 로드 (videoCounts: \(channels.map { "\($0.name):\($0.videoCount)" }.joined(separator: ", ")))")
            // Try pending channel data first (most reliable for new windows)
            if let data = pendingChannelData,
               let chId = data["channelId"] as? String,
               let chName = data["channelName"] as? String {
                let handle = (data["channelHandle"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let ch = SubscribedChannel(
                    id: chId, name: chName, handle: handle,
                    avatarURL: data["channelAvatarURL"] as? String ?? "",
                    subscriberCount: (data["channelSubscriberCount"] as? Int).flatMap { $0 == 0 ? nil : $0 },
                    videoCount: data["channelVideoCount"] as? Int ?? 0
                )
                if !channels.contains(where: { $0.id == chId }) {
                    channels.insert(ch, at: 0)
                    SubscribedChannel.saveAll(channels)
                }
                let target = channels.first(where: { $0.id == chId }) ?? ch
                DebugLogManager.shared?.append("[Channel] ▶️ 초기 채널 선택: \(target.name) (videoCount=\(target.videoCount))")
                selectedChannel = target
                loadVideos(for: target)
                if target.avatarURL.isEmpty {
                    refreshChannelInfo(for: ch)
                }
            } else if let id = initialChannelId, let channel = channels.first(where: { $0.id == id }) {
                DebugLogManager.shared?.append("[Channel] ▶️ 초기 채널 선택: \(channel.name) (videoCount=\(channel.videoCount))")
                selectedChannel = channel
                loadVideos(for: channel)
                if channel.avatarURL.isEmpty {
                    refreshChannelInfo(for: channel)
                }
            } else if let id = initialChannelId {
                DebugLogManager.shared?.append("[Channel] ⚠️ 초기 채널 ID 없음: \(id)")
            } else {
                DebugLogManager.shared?.append("[Channel] ℹ️ onAppear: 초기 채널 없음")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.openChannelWithIdNotification)) { notification in
            let info = (notification.userInfo as? [String: Any]) ?? [:]
            DebugLogManager.shared?.append("[Channel] 📬 openChannelWithIdNotification received: \(info["channelId"] ?? "nil")")
            self.handleChannelNotification(info)
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.selectChannelNotification)) { notification in
            let info = (notification.userInfo as? [String: Any]) ?? [:]
            DebugLogManager.shared?.append("[Channel] 📬 selectChannelNotification received: \(info["channelId"] ?? "nil")")
            self.handleChannelNotification(info)
        }
        .alwaysOnTop(isPinned, windowIdentifier: "channel")
        .sheet(isPresented: $isShowingAddDialog) {
            addChannelDialog
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isPinned.toggle()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                }
                .help(isPinned ? "최상위 고정 해제" : "항상 최상위로 표시")

                Button {
                    NSApp.keyWindow?.orderOut(nil)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("창 닫기")
            }
        }
    }

    private var addChannelDialog: some View {
        VStack(spacing: 16) {
            Text("채널 추가")
                .font(.headline)
            TextField("YouTube 채널 URL", text: $addChannelURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            HStack(spacing: 12) {
                Button("취소") {
                    isShowingAddDialog = false
                    addChannelURL = ""
                }
                Button("추가") {
                    addChannel()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(addChannelURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func addChannel() {
        let url = addChannelURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        isShowingAddDialog = false
        addChannelURL = ""
        isAddingChannel = true

        Task {
            do {
                let service = ChannelFetchService()
                await MainActor.run {
                    DebugLogManager.shared?.append("[Channel] 채널 정보 조회: \(url)")
                }
                let channel = try await service.fetchChannelInfo(from: url)
                await MainActor.run {
                    DebugLogManager.shared?.append("[Channel] ✅ \(channel.name) (구독자 \(channel.subscriberCount ?? 0))")
                    if let existing = channels.first(where: { $0.id == channel.id }) {
                        selectedChannel = existing
                        loadVideos(for: existing)
                    } else {
                        channels.insert(channel, at: 0)
                        SubscribedChannel.saveAll(channels)
                        selectedChannel = channel
                        loadVideos(for: channel)
                    }
                    isAddingChannel = false
                }
            } catch {
                await MainActor.run {
                    isAddingChannel = false
                    DebugLogManager.shared?.append("[Channel] ❌ 채널 추가 실패: \(error.localizedDescription)")
                    let alert = NSAlert()
                    alert.messageText = "채널을 추가할 수 없습니다"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    private func loadVideos(for channel: SubscribedChannel, force: Bool = false) {
        let lastFetch = ChannelDownloadCache.lastFetchDate(channelId: channel.id)
        let isFresh = Date().timeIntervalSince(lastFetch) < 86400

        if !force, isFresh, let cached = ChannelDownloadCache.cachedVideos(channelId: channel.id) {
            channelVideos = cached
            DebugLogManager.shared?.append("[Channel] ⏩ 캐시된 영상 목록 사용 (24h, \(cached.count)개)")
            updateVideoCount(for: channel, count: cached.count)
            return
        }

        // Use stale cache if available, but refresh in background
        if !force, let cached = ChannelDownloadCache.cachedVideos(channelId: channel.id) {
            channelVideos = cached
            updateVideoCount(for: channel, count: cached.count)
            DebugLogManager.shared?.append("[Channel] ⏩ 캐시된 영상 사용 (stale, \(cached.count)개, background refresh)")
        } else {
            isLoadingVideos = true
            channelVideos = force ? [] : channelVideos
            if force { channelVideos = [] }
        }

        DebugLogManager.shared?.append("[Channel] ▶️ 영상 목록 로딩: \(channel.name)")

        channelLoadCount = 0
        channelLoadTotal = channel.videoCount > 0 ? channel.videoCount : 0
        channelLoadEstimate = nil
        channelLoadProbeDone = false
        channelLoadStart = Date()

        loadGeneration += 1
        let gen = loadGeneration

        fetchTask?.cancel()
        fetchTask = Task {
            defer {
                Task { @MainActor in
                    guard self.loadGeneration == gen else { return }
                    self.fetchTask = nil
                    self.channelLoadStart = nil
                }
            }
            do {
                let service = ChannelFetchService()
                let estimatedTotal = self.channelLoadTotal
                if estimatedTotal >= 100 {
                    if let est = try? await service.estimateLoadDuration(
                        channelId: channel.id,
                        handle: channel.handle,
                        totalCount: estimatedTotal
                    ), est > 0 {
                        await MainActor.run {
                            guard self.loadGeneration == gen else { return }
                            self.channelLoadEstimate = est
                            DebugLogManager.shared?.append("[Channel] ⏱ 예상 소요 \(String(format: "%.0f", est))초")
                        }
                    }
                    await MainActor.run {
                        guard self.loadGeneration == gen else { return }
                        self.channelLoadProbeDone = true
                    }
                }
                ChannelDownloadCache.clearVideoCache(channelId: channel.id)
                let (videos, count) = try await service.fetchAllVideos(
                    channelId: channel.id,
                    handle: channel.handle,
                    progressHandler: { loaded in
                        Task { @MainActor in
                            self.channelLoadCount = loaded
                        }
                    }
                )
                try Task.checkCancellation()
                await MainActor.run {
                    channelVideos = videos
                    ChannelDownloadCache.setCachedVideos(channelId: channel.id, videos: videos)
                    isLoadingVideos = false
                    DebugLogManager.shared?.append("[Channel] ✅ 영상 \(count)개 로드 완료")
                    ChannelDownloadCache.markFetchDate(channelId: channel.id)
                    self.updateVideoCount(for: channel, count: count)
                }
                // Sync downloaded IDs from disk (recover any missing entries)
                BookmarkManager.ensureAccess()
                ChannelDownloadCache.syncDownloadedIDsFromDisk(channelName: channel.name)

                // Rename 000-prefixed files with correct sequential index
                ChannelDownloadCache.renameZeroIndexedFiles(channelName: channel.name, videos: videos, totalCount: count)

                // Update library items with channel upload index
                let updates = videos.compactMap { v -> (videoId: String, uploadIndex: Int)? in
                    let idx = count - v.playlistIndex + 1
                    return idx > 0 ? (v.id, idx) : nil
                }
                LibraryCacheService.shared.updateChannelUploadIndices(channelId: channel.id, updates)

                // Refresh library in-memory state from disk
                store.send(.library(.loadFromDisk))
            } catch is CancellationError {
                DebugLogManager.shared?.append("[Channel] ⛔ 영상 로드 취소됨")
            } catch {
                await MainActor.run {
                    isLoadingVideos = false
                    DebugLogManager.shared?.append("[Channel] ❌ 영상 로드 실패: \(error.localizedDescription)")
                    errorMessage = "영상 목록을 불러올 수 없습니다: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateVideoCount(for channel: SubscribedChannel, count: Int) {
        guard let idx = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        let updated = SubscribedChannel(
            id: channel.id,
            name: channel.name,
            handle: channel.handle,
            avatarURL: channel.avatarURL,
            subscriberCount: channel.subscriberCount,
            videoCount: count
        )
        channels[idx] = updated
        if selectedChannel?.id == channel.id {
            selectedChannel = updated
        }
        SubscribedChannel.saveAll(channels)
    }

    private func refreshChannelInfo(for channel: SubscribedChannel) {
        DebugLogManager.shared?.append("[Channel] ▶️ 채널 정보 갱신: \(channel.name)")

        Task {
            do {
                let service = ChannelFetchService()
                let url: String
                if let handle = channel.handle, !handle.isEmpty {
                    url = "https://www.youtube.com/\(handle)"
                } else if channel.id.hasPrefix("UC"), channel.id.count == 24 {
                    url = "https://www.youtube.com/channel/\(channel.id)"
                } else {
                    url = "https://www.youtube.com/channel/\(channel.id)"
                }
                let updated = try await service.fetchChannelInfo(from: url)
                await MainActor.run {
                    if let idx = channels.firstIndex(where: { $0.id == channel.id }) {
                        let existingCount = channels[idx].videoCount
                        let finalChannel = SubscribedChannel(
                            id: updated.id,
                            name: updated.name,
                            handle: updated.handle,
                            avatarURL: updated.avatarURL,
                            subscriberCount: updated.subscriberCount,
                            videoCount: existingCount > 0 ? existingCount : updated.videoCount
                        )
                        channels[idx] = finalChannel
                        if selectedChannel?.id == channel.id {
                            selectedChannel = finalChannel
                        }
                        SubscribedChannel.saveAll(channels)
                    }
                    DebugLogManager.shared?.append("[Channel] ✅ 채널 정보 갱신 완료: \(updated.name)")
                }
                if !updated.avatarURL.isEmpty,
                   let avatarURL = URL(string: updated.avatarURL),
                   let (data, _) = try? await URLSession.shared.data(from: avatarURL),
                   let img = NSImage(data: data) {
                    LibraryCacheService.shared.cacheAvatar(for: updated.id, data: data)
                    await MainActor.run {
                        DebugLogManager.shared?.append("[Channel] 🖼️ 아바타 캐시 갱신 완료 (\(img.size.width)x\(img.size.height))")
                    }
                }
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Constants.channelInfoDidUpdateNotification,
                        object: nil,
                        userInfo: ["channelId": updated.id]
                    )
                }
            } catch {
                await MainActor.run {
                    DebugLogManager.shared?.append("[Channel] ❌ 채널 정보 갱신 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleChannelNotification(_ info: [String: Any]) {
        DebugLogManager.shared?.append("[Channel] 📨 채널 선택 알림 수신: chId=\(info["channelId"] ?? "nil"), currentSelected=\(selectedChannel?.id ?? "nil")(vc=\(selectedChannel?.videoCount ?? -1))")
        if let chId = info["channelId"] as? String,
           let chName = info["channelName"] as? String {
            // 이미 같은 채널이 로드되어 있으면 중복 처리하지 않음
            if selectedChannel?.id == chId, selectedChannel?.videoCount ?? 0 > 0 {
                DebugLogManager.shared?.append("[Channel] ⏩ 이미 로드된 채널, 스킵 (videoCount=\(selectedChannel?.videoCount ?? 0))")
                return
            }
            let handle = (info["channelHandle"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let ch = SubscribedChannel(
                id: chId, name: chName, handle: handle,
                avatarURL: info["channelAvatarURL"] as? String ?? "",
                subscriberCount: (info["channelSubscriberCount"] as? Int).flatMap { $0 == 0 ? nil : $0 },
                videoCount: info["channelVideoCount"] as? Int ?? 0
            )
            if !channels.contains(where: { $0.id == chId }) {
                channels.insert(ch, at: 0)
                SubscribedChannel.saveAll(channels)
            }
            let target = channels.first(where: { $0.id == chId }) ?? ch
            DebugLogManager.shared?.append("[Channel] ▶️ 채널 선택: \(target.name) (videoCount=\(target.videoCount), channels에서 찾음=\(channels.contains(where: { $0.id == chId })))")
            selectedChannel = target
            loadVideos(for: target)
            if target.avatarURL.isEmpty {
                refreshChannelInfo(for: target)
            }
        } else if let channelId = info["channelId"] as? String {
            DebugLogManager.shared?.append("[Channel] 📨 채널 ID만 수신: \(channelId)")
            channels = SubscribedChannel.loadAll()
            if let channel = channels.first(where: { $0.id == channelId }) {
                DebugLogManager.shared?.append("[Channel] ▶️ 채널 선택: \(channel.name) (videoCount=\(channel.videoCount))")
                selectedChannel = channel
                loadVideos(for: channel)
            } else {
                DebugLogManager.shared?.append("[Channel] ⚠️ 저장된 채널에서 ID 못찾음: \(channelId)")
            }
        }
    }

    private func deleteChannel(_ channel: SubscribedChannel) {
        let alert = NSAlert()
        alert.messageText = "채널 \"\(channel.name)\"을 삭제합니다"
        alert.informativeText = "모든 다운로드 파일과 데이터가 삭제됩니다. 정말 삭제하시겠습니까?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        // Remove channel folder
        let folderPath = "\(Constants.channelStorageDirectory)/\(Constants.sanitizeFolderName(channel.name))"
        BookmarkManager.ensureAccess()
        try? FileManager.default.removeItem(atPath: folderPath)

        // Remove download cache (file-based, inside channel folder — already deleted above)
        ChannelDownloadCache.removeChannel(channel.name)
        ChannelDownloadCache.clearVideoCache(channelId: channel.id)
        ChannelDownloadCache.clearFetchDate(channelId: channel.id)

        // Remove from library
        store.send(.library(.removeItemsByChannel(channelId: channel.id, channelName: channel.name)))

        // Remove from list
        channels.removeAll { $0.id == channel.id }
        SubscribedChannel.saveAll(channels)

        if selectedChannel?.id == channel.id {
            selectedChannel = nil
            channelVideos = []
        }
    }


}

