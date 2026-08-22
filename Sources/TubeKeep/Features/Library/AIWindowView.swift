import SwiftUI
import AppKit
import ComposableArchitecture

// MARK: - AI 윈도우

struct AIWindowView: View {
    let store: StoreOf<AppReducer>
    @State private var playbackTime: TimeInterval = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var channelAvatar: NSImage?
    @State private var alwaysOnTop = false

    @State private var podcastTotalDuration: TimeInterval = 0

    private var currentItem: LibraryItem? {
        guard let videoId = store.library.librarySummaryVideoId ?? store.library.qna.selectedVideoId else { return nil }
        return store.library.items.first(where: { $0.id == videoId })
    }

    var body: some View {
        VStack(spacing: 0) {
            videoHeader
                .padding(.bottom, 4)
            Divider()
            contentArea
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if store.library.librarySummaryLoading {
                ZStack {
                    AppColors.hoverRow
                        .background(.regularMaterial)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        let msg = store.library.summaryProgressMessage
                        Text(msg.isEmpty ? "요약 정보를 불러오는 중..." : msg)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.default, value: store.library.summaryProgressMessage)
            }
        }
        .alwaysOnTop(alwaysOnTop, windowIdentifier: "ai")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    alwaysOnTop.toggle()
                } label: {
                    Image(systemName: alwaysOnTop ? "pin.fill" : "pin")
                }
                .help(alwaysOnTop ? "최상위 고정 해제" : "항상 최상위로 표시")
            }
        }
        .onAppear {
            store.send(.library(.loadFromDisk))
            if let videoId = store.library.qna.selectedVideoId {
                store.send(.library(.qna(.loadQnAHistory(videoId))))
            }
            loadChannelAvatar()
        }
        .onChange(of: store.library.librarySummaryVideoId) { _, _ in
            loadChannelAvatar()
            if let videoId = store.library.qna.selectedVideoId {
                store.send(.library(.qna(.loadQnAHistory(videoId))))
            }
        }
        .onChange(of: store.library.qna.selectedVideoId) { _, newVideoId in
            if let videoId = newVideoId {
                store.send(.library(.qna(.loadQnAHistory(videoId))))
            }
        }
    }

    // MARK: - Video Header

    @ViewBuilder
    private var videoHeader: some View {
        if let item = currentItem {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                CachedThumbnailView(videoId: item.id, url: item.thumbnailURL)
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    // Title
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .frame(height: 34, alignment: .top)

                    // Channel avatar + name + badges
                    HStack(spacing: 4) {
                        if let avatar = channelAvatar {
                            Image(nsImage: avatar)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                        }
                        Button {
                            store.send(.library(.openChannelDownload(channelId: item.channelId, channelName: item.channelName)))
                        } label: {
                            Text(item.channelName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            + Text(" ▸")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        statusIcons
                    }

                    // Duration + dates + podcast
                    HStack(spacing: 6) {
                        if let duration = item.duration, duration > 0 {
                            Text(formatDuration(duration))
                                .font(.system(size: 10, design: .monospaced))
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        if let uploadDate = item.uploadDate {
                            Text("업로드 \(formatShortDate(uploadDate))")
                                .font(.system(size: 10))
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("다운로드 \(formatShortDate(item.downloadDate))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Spacer()

                        headerPodcastControls
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var headerPodcastControls: some View {
        if let videoId = store.library.librarySummaryVideoId {
            let isGenerating = store.library.podcast.generatingIds.contains(videoId)
            let hasPodcast = store.library.podcast.availableIds.contains(videoId)
            let isPlaying = store.library.podcast.playingId == videoId

            HStack(spacing: 4) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    let podcastMsg = store.library.podcast.progressMessage
                    if !podcastMsg.isEmpty {
                        Text(podcastMsg)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else if hasPodcast {
                    if isPlaying {
                        Text("\(formatTime(playbackTime))/\(formatTime(podcastTotalDuration))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }

                    Button {
                        if isPlaying {
                            store.send(.library(.podcast(.pausePodcast)))
                        } else {
                            store.send(.library(.podcast(.playPodcast(videoId))))
                        }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.library(.podcast(.stopPodcast)))
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.library(.podcast(.deletePodcast(videoId))))
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                } else {
                    Button {
                        store.send(.library(.podcast(.generatePodcast(videoId))))
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
            .onAppear { startPlaybackTimer() }
            .onDisappear { stopPlaybackTimer() }
        }
    }

    @ViewBuilder
    private var statusIcons: some View {
        if let item = currentItem {
            HStack(spacing: 6) {
                statusBadge(icon: "captions.bubble.fill", available: store.library.subtitleAvailableIds.contains(item.id), label: "자막")
                statusBadge(icon: "doc.text.fill", available: item.summary != nil && !(item.summary?.isEmpty ?? true), label: "요약")
                statusBadge(icon: "list.number", available: item.chapters != nil, label: "챕터")
                statusBadge(icon: "mic.fill", available: store.library.podcast.availableIds.contains(item.id), label: "팟캐스트")
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private func statusBadge(icon: String, available: Bool, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(available ? Color.accentColor.opacity(0.15) : AppColors.hoverRow)
        .foregroundStyle(available ? Color.accentColor : Color.secondary.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 0) {
            // Summary + Chapters (상단, independent scrolls, 50/50 split)
            HStack(alignment: .top, spacing: 0) {
                AISummarySection(store: store)
                    .frame(maxWidth: .infinity)
                Divider()
                AIChapterSection(store: store)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 200)

            Divider()

            // Mindmap + Q&A (하단, 좌우 split)
            if let videoId = store.library.librarySummaryVideoId {
                HStack(alignment: .top, spacing: 0) {
                    AIMindmapSection(store: store, videoId: videoId)
                        .frame(maxWidth: .infinity)
                    Divider()
                    AIQnASection(store: store)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            } else {
                AIQnASection(store: store)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func loadChannelAvatar() {
        guard let item = currentItem else { return }
        let channels = SubscribedChannel.loadAll()
        if let channel = channels.first(where: { $0.id == item.channelId }),
           !channel.avatarURL.isEmpty,
           let url = URL(string: channel.avatarURL) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = NSImage(data: data) {
                    await MainActor.run { channelAvatar = img }
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: date)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        updatePlaybackTime()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updatePlaybackTime()
        }
    }

    private func stopPlaybackTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePlaybackTime() {
        playbackTime = PodcastService.shared.currentTime
        playbackDuration = PodcastService.shared.duration
        podcastTotalDuration = PodcastService.shared.duration
    }
}