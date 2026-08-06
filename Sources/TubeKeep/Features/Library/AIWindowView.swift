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
                    Color.primary.opacity(0.05)
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

                Button {
                    NSApp.keyWindow?.orderOut(nil)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("창 닫기")
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
                                .font(.system(size: 9))
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
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else if hasPodcast {
                    if isPlaying {
                        Text("\(formatTime(playbackTime))/\(formatTime(podcastTotalDuration))")
                            .font(.system(size: 9, design: .monospaced))
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
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.library(.podcast(.stopPodcast)))
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.library(.podcast(.deletePodcast(videoId))))
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                } else {
                    Button {
                        store.send(.library(.podcast(.generatePodcast(videoId))))
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9))
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
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 8))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(available ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
        .foregroundStyle(available ? Color.accentColor : Color.secondary.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 0) {
            // Summary + Chapters (상단, independent scrolls, 50/50 split)
            HStack(alignment: .top, spacing: 0) {
                summarySection
                    .frame(maxWidth: .infinity)
                Divider()
                chapterSection
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 200)

            Divider()

            // Mindmap + Q&A (하단, 좌우 split)
            if let videoId = store.library.librarySummaryVideoId {
                HStack(alignment: .top, spacing: 0) {
                    mindmapSection(for: videoId)
                        .frame(maxWidth: .infinity)
                    Divider()
                    qnaSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            } else {
                qnaSection
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        let summaryText: String? = store.library.librarySummaryText ?? currentItem?.summary
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("요약 정보")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if let text = summaryText, !text.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                if let videoId = store.library.librarySummaryVideoId {
                    Button {
                        store.send(.library(.resummarize(videoId)))
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if store.library.librarySummaryLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("요약 중...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let text = summaryText, !text.isEmpty {
                ScrollView {
                    Text(stripChaptersSection(text))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                Text("요약 없음")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.trailing, 4)
    }

    // MARK: - Chapters

    @ViewBuilder
    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("챕터")
                .font(.system(size: 11, weight: .semibold))

            if let item = currentItem,
               let chapters = chaptersForItem(item) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(chapters) { chapter in
                            Button {
                                store.send(.library(.qna(.seekToTimestamp(chapter.startTime))))
                            } label: {
                                HStack(spacing: 6) {
                                    Text(chapter.startTimeFormatted)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 42, alignment: .leading)
                                    Text(chapter.title)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("챕터 없음")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.leading, 8)
    }

    private func chaptersForItem(_ item: LibraryItem) -> [ChapterInfo]? {
        if let chaptersData = item.chapters,
           let chapters = try? JSONDecoder().decode([ChapterInfo].self, from: chaptersData),
           !chapters.isEmpty {
            return chapters
        }
        if let summaryText = store.library.librarySummaryText {
            return extractChaptersFromSummary(summaryText)
        }
        if let summaryText = item.summary {
            return extractChaptersFromSummary(summaryText)
        }
        return nil
    }

    private func extractChaptersFromSummary(_ text: String) -> [ChapterInfo]? {
        var chapters: [ChapterInfo] = []
        let lines = text.components(separatedBy: .newlines)
        var foundChapters = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("챕터:") || trimmed.hasPrefix("챕터 :") || trimmed.hasPrefix("Chapters:") || trimmed.hasPrefix("chapters:") {
                foundChapters = true
                continue
            }
            if foundChapters {
                if let chapter = SummarizationService.parseChapterLineStatic(trimmed) {
                    chapters.append(chapter)
                } else if !trimmed.isEmpty && !trimmed.hasPrefix("•") && !trimmed.hasPrefix("-") {
                    break
                }
            }
        }
        return chapters.isEmpty ? nil : chapters
    }

    // MARK: - Mindmap

    @ViewBuilder
    private func mindmapSection(for videoId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("마인드맵")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if store.library.mindmap.node == nil, !store.library.mindmap.loading {
                    Button {
                        store.send(.library(.mindmap(.generateMindmap(videoId))))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                            Text("마인드맵 생성")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            if store.library.mindmap.node == nil, !store.library.mindmap.loading {
                Text("마인드맵 생성 버튼을 눌러 생성하세요")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            }

            if store.library.mindmap.loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("마인드맵 생성 중...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if let node = store.library.mindmap.node {
                ScrollView {
                    MindmapTreeView(node: node, store: store)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let error = store.library.mindmap.error {
                ErrorBanner(message: error)
            }
        }
        .padding(.trailing, 4)
    }

    // MARK: - Q&A

    @ViewBuilder
    private var qnaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("질문")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }

            QAInputBar(store: store)

            if store.library.qna.loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("답변 생성 중...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if let error = store.library.qna.error {
                ErrorBanner(message: error)
            }

            if store.library.qna.historyItems.isEmpty && !store.library.qna.loading {
                Text("질문을 입력해주세요")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.library.qna.historyItems) { item in
                            qaHistoryItem(item)
                        }
                    }
                }
            }
        }
        .padding(.leading, 8)
    }

    @ViewBuilder
    private func qaHistoryItem(_ item: QAHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Q: \(item.question)")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                Spacer()
                Button {
                    store.send(.library(.qna(.deleteQnAHistoryItem(item.id))))
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }

            if !item.timestamps.isEmpty {
                // 챕터 형식으로 타임스탬프 표시
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(item.timestamps) { ts in
                        Button {
                            store.send(.library(.qna(.seekToTimestamp(ts.startTime))))
                        } label: {
                            HStack(alignment: .top, spacing: 4) {
                                Text(ts.time)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 30, alignment: .leading)
                                Text(ts.description.isEmpty ? item.answer : ts.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("A: \(item.answer)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(6)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func stripChaptersSection(_ text: String) -> String {
        let patterns = ["챕터:", "챕터 :", "Chapters:", "chapters:"]
        var result = text
        for pattern in patterns {
            if let range = result.range(of: pattern) {
                result = String(result[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return result
    }

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