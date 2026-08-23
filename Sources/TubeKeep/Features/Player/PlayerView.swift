import SwiftUI
import AppKit
import ComposableArchitecture

struct PlayerView: View {
    let store: StoreOf<PlayerReducer>
    let appStore: StoreOf<AppReducer>
    @StateObject private var mpv = MPVClient()
    @State private var window: NSWindow?
    @State private var volume: Double = 100
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    @State private var similarThumbnails: [String: NSImage] = [:]
    @State private var isRepeatEnabled = false
    @State private var controlsVisible = true
    @State private var controlsHideTask: Task<Void, Never>?

    private let videoWidth: CGFloat = 854
    private let videoHeight: CGFloat = 480
    private let controlBarHeight: CGFloat = 44
    private let panelWidth: CGFloat = 320

    private var windowWidth: CGFloat { videoWidth + (store.showQueue || store.showSubtitlePanel || store.showSimilarVideos || store.showAIPanel ? panelWidth : 0) }
    private var windowHeight: CGFloat { videoHeight }

    var body: some View {
        HStack(spacing: 0) {
            videoArea
            rightPanel
        }
        .frame(minWidth: windowWidth, maxWidth: .infinity, minHeight: windowHeight, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alwaysOnTop(store.isAlwaysOnTop, windowIdentifier: "player")
        .toolbar { toolbarContent }
        .modifier(PlaybackReactionsModifier(
            store: store,
            mpv: mpv,
            windowProvider: { window },
            setContentSize: { window?.setContentSize(NSSize(width: windowWidth, height: windowHeight)) },
            stopAndSetup: { setupPlayer() },
            setupPlayer: { setupPlayer() }
        ))
        .background(WindowAccessor { win in DispatchQueue.main.async { window = win } })
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notif in
            guard (notif.object as? NSWindow) == window else { return }
            mpv.stop()
            // 창이 닫히면 렌더 루프도 정지 — 유휴 CPU/GPU 소모 방지 (T-1208)
            mpv.pauseRendering()
            // @State window ↔ HostingView rootView 사이클을 끊는다.
            // 이 참조가 남으면 윈도우+뷰트리+MPVClient가 통째로 누적됨 (T-1208)
            window = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.playerHideNotification)) { notif in
            guard (notif.object as? NSWindow) == window else { return }
            // 창은 숨김(orderOut)으로 유지되므로 willClose가 불리지 않는다.
            // 숨김 시점에 재생·렌더 루프를 직접 정지한다. (T-1208)
            #if DEBUG
            DebugLogManager.shared?.append("[PlayerView] hide — mpv 정지")
            #endif
            mpv.stop()
            mpv.pauseRendering()
        }
        .onAppear {
            #if DEBUG
            DebugLogManager.shared?.append("[PlayerView] appear — mpv=\(ObjectIdentifier(mpv).hashValue)")
            #endif
        }
        .onDisappear {
            #if DEBUG
            DebugLogManager.shared?.append("[PlayerView] disappear — mpv=\(ObjectIdentifier(mpv).hashValue)")
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.playerVolumeChangeNotification)) { notif in
            guard let delta = notif.userInfo?["delta"] as? Double else { return }
            let newVolume = min(max(volume + delta, 0), 100)
            volume = newVolume
            mpv.setVolume(newVolume)
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.playerToggleQueueNotification)) { notif in
            guard let postWindow = notif.object as? NSWindow,
                  let win = window,
                  postWindow === win else { return }
            store.send(.toggleQueue)
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.playerToggleSubtitlePanelNotification)) { notif in
            guard let postWindow = notif.object as? NSWindow,
                  let win = window,
                  postWindow === win else { return }
            store.send(.toggleSubtitlePanel)
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.playerToggleSimilarVideosNotification)) { notif in
            guard let postWindow = notif.object as? NSWindow,
                  let win = window,
                  postWindow === win else { return }
            store.send(.toggleSimilarVideos)
        }
        .onChange(of: store.showAIPanel) { _, visible in
            window?.setContentSize(NSSize(width: windowWidth, height: windowHeight))
            if visible { loadAISummaryForCurrentVideo() }
        }
    }

    private func loadAISummaryForCurrentVideo() {
        if let videoId = store.playerItem.videoId {
            appStore.send(.library(.showSummaryInPanel(videoId)))
        }
    }

    private struct PlaybackReactionsModifier: ViewModifier {
        let store: StoreOf<PlayerReducer>
        let mpv: MPVClient
        let windowProvider: () -> NSWindow?
        let setContentSize: () -> Void
        let stopAndSetup: () -> Void
        let setupPlayer: () -> Void

        func body(content: Content) -> some View {
            content
                .onDisappear { mpv.stop() }
                .onChange(of: mpv.isRenderReady) { _, ready in if ready { setupPlayer() } }
                .onChange(of: store.playerItemId) { _, _ in stopAndSetup() }
                .onChange(of: store.streamURL) { _, newURL in
                    if newURL != nil, store.playerItem.fileURL == nil { stopAndSetup() }
                }
                .onReceive(NotificationCenter.default.publisher(for: Constants.playerSeekNotification)) { notif in
                    guard let direction = notif.userInfo?["direction"] as? Double else { return }
                    let step = Settings.loadSettings().seekStepSeconds
                    mpv.seekRelative(direction * step)
                }
                .onReceive(NotificationCenter.default.publisher(for: Constants.playerTogglePlayPauseNotification)) { notif in
                    // keyDown은 keyWindow에서만 발생하므로 post한 PlayerWindow와 자기 창이
                    // 일치할 때만 토글한다. (잔존 PlayerView가 여럿이어도 1회만 처리)
                    guard let postWindow = notif.object as? NSWindow,
                          let win = windowProvider(),
                          postWindow === win else { return }
                    #if DEBUG
                    DebugLogManager.shared?.append("[PlayerView] toggle received — isLoaded=\(mpv.isLoaded) isPlaying=\(mpv.isPlaying)")
                    #endif
                    // EOF 후에도 스페이스바로 다시 재생할 수 있어야 하므로
                    // isLoaded/isPlaying 조건 없이 항상 토글한다. (mpv nil 가드는 내부에 있음)
                    mpv.togglePlayPause()
                }
                .onChange(of: store.showSubtitlePanel) { _, _ in setContentSize() }
                .onChange(of: store.showQueue) { _, _ in setContentSize() }
                .onChange(of: store.showSimilarVideos) { _, _ in setContentSize() }
                .onChange(of: mpv.currentTime) { _, newTime in
                    if store.playerItem.videoId != nil, !mpv.isFinished, newTime > 0 {
                        store.send(.timeUpdated(newTime))
                    }
                }
                .onChange(of: mpv.duration) { _, newDur in
                    if newDur > 0 { store.send(.durationUpdated(newDur)) }
                }
                .onChange(of: mpv.isPlaying) { _, newVal in store.send(.playingChanged(newVal)) }
                .onChange(of: store.playbackRate) { _, newVal in mpv.setPlaybackRate(newVal) }
                .onChange(of: store.aLoop) { _, newVal in
                    if let a = newVal { mpv.setALoop(at: a) } else { mpv.clearABLoop() }
                }
                .onChange(of: store.bLoop) { _, newVal in
                    if let b = newVal {
                        mpv.setBLoop(at: b)
                        if let a = store.aLoop { mpv.seek(to: a) }
                    }
                }
                .onChange(of: mpv.isFinished) { _, newVal in if newVal { store.send(.videoDidEnd) } }
                .onChange(of: mpv.error) { _, newVal in if newVal != nil { mpv.stop() } }
                .onChange(of: store.playerItem.title) { _, newTitle in
                    if let win = windowProvider() { win.title = newTitle }
                }
        }
    }

    private var rightPanel: some View {
        Group {
            if store.showQueue {
                queuePanel.frame(width: panelWidth)
            } else if store.showSubtitlePanel {
                subtitlePanel.frame(width: panelWidth)
            } else if store.showSimilarVideos {
                similarVideosPanel.frame(width: panelWidth)
            } else if store.showAIPanel {
                aiPanel.frame(width: panelWidth)
            }
        }
    }

    // MARK: - Video Area

    private var videoArea: some View {
        GeometryReader { geo in
            // 정수로 반올림해 소수점 프레임의 연속 리사이즈(reshape 빈발)를 방지한다. (T-1206)
            let fittedHeight = round(min(geo.size.height, geo.size.width * 9 / 16))
            let fittedWidth = round(fittedHeight * 16 / 9)
            ZStack {
                Color.black
                ZStack {
                    playbackView
                    if store.isStreamLoading || (!mpv.isLoaded && store.playerItem.videoId != nil) {
                        loadingView
                    }
                    if store.fileMissing { fileMissingView }
                    if let err = mpv.error { errorView(err) }
                    if store.showSubtitleOverlay {
                        SubtitleOverlay(cues: store.subtitles, currentTime: mpv.currentTime)
                    }
                    if store.showUpNext { upNextOverlay.transition(.opacity) }
                    if let msg = store.clipSaveMessage {
                        clipMessageBanner(msg)
                            .transition(.opacity)
                    }
                    VStack {
                        Spacer()
                        controlBar
                            .frame(height: controlBarHeight)
                            .background(.ultraThinMaterial)
                            .opacity(controlsVisible ? 1 : 0)
                            .offset(y: controlsVisible ? 0 : controlBarHeight)
                            .allowsHitTesting(controlsVisible)
                    }
                }
                .frame(width: fittedWidth, height: fittedHeight)
                fullscreenButton
                    .opacity(controlsVisible ? 1 : 0)
            }
            .clipped()
            .onTapGesture(count: 1) { store.send(.toggleSubtitleOverlay) }
            .onTapGesture(count: 2) { toggleFullscreen() }
            .onContinuousHover { phase in
                switch phase {
                case .active, .ended:
                    scheduleControlsHide()
                }
            }
            .animation(.easeOut(duration: 0.2), value: controlsVisible)
        }
        .frame(minWidth: videoWidth, minHeight: videoHeight)
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsVisible = true
        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.5)
            Text(store.isStreamLoading ? "스트리밍 URL을 가져오는 중..." : "재생 준비 중...")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
        }
    }

    private var playbackView: some View {
        ZStack {
            MPVVideoView(client: mpv)
            if mpv.isLoaded && !mpv.hasVideo {
                VStack(spacing: 16) {
                    Image(systemName: "music.note").font(.system(size: 48)).foregroundColor(.white.opacity(0.5))
                    Text("오디오 파일").font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var fileMissingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 48)).foregroundColor(.white.opacity(0.5))
            Text("파일을 찾을 수 없음").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.7))
            Text("디스크에서 파일이 삭제되었습니다").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
            if let videoId = store.playerItem.videoId {
                Button("보관함에서 제거") { store.send(.removeFromLibrary(videoId)) }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
            }
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundColor(.white.opacity(0.5))
            Text(msg).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
        }
    }

    private var fullscreenButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { toggleFullscreen() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14)).foregroundColor(.white).padding(6)
                        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain).help("전체 화면").padding(8)
            }
            Spacer()
        }
    }

    // MARK: - Subtitle Panel

    private var subtitlePanel: some View {
        SubtitlePanel(
            cues: store.subtitles,
            currentTime: mpv.currentTime,
            subtitleState: store.subtitleState,
            isTranscribing: store.isTranscribing,
            transcribeError: store.transcribeError,
            whisperProgressMessage: store.whisperProgressMessage,
            onSeek: { mpv.seek(to: $0) },
            onDownloadSubtitles: store.playerItem.videoId != nil ? { store.send(.downloadSubtitles) } : nil,
            onTranscribe: store.playerItem.fileURL != nil ? { store.send(.transcribeWithWhisper) } : nil,
            onDeleteSubtitles: store.playerItem.videoId != nil ? { store.send(.deleteSubtitles) } : nil,
            onOpenWhisperSettings: { NotificationCenter.default.post(name: Constants.openWhisperSettingsNotification, object: nil) }
        )
    }

    // MARK: - Similar Videos Panel

    private var similarVideosPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("비슷한 영상").font(.system(size: 13, weight: .semibold))
                Spacer()
                if store.isLoadingSimilar {
                    ProgressView().controlSize(.mini)
                } else if !store.similarVideos.isEmpty {
                    Button { store.send(.loadSimilarVideos) } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11))
                    }.buttonStyle(.plain).help("새로고침")
                }
                Button { store.send(.clearSimilarVideos); store.send(.toggleSimilarVideos) } label: {
                    Image(systemName: "xmark").font(.system(size: 11))
                }.buttonStyle(.plain).help("닫기")
            }
            .padding(10)

            Divider()

            if store.isLoadingSimilar {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView("검색어 생성 및 영상 검색 중...").controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let err = store.similarError {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 22)).foregroundStyle(.orange)
                    Text(err).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("재시도") { store.send(.loadSimilarVideos) }.controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            } else if store.similarVideos.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "sparkles.rectangle.stack").font(.system(size: 24)).foregroundStyle(.secondary)
                    Text("비슷한 영상을 찾지 못했습니다").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.similarVideos) { video in
                            similarVideoRow(video)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func similarVideoRow(_ video: TrendingVideo) -> some View {
        Button { openSimilar(video) } label: {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if let img = similarThumbnails[video.id] {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(nsColor: .underPageBackgroundColor)
                            .overlay(Image(systemName: "video").font(.system(size: 14)).foregroundStyle(.secondary))
                    }
                }
                .frame(width: 120, height: 68)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onAppear { loadSimilarThumbnail(for: video) }

                VStack(alignment: .leading, spacing: 3) {
                    Text(video.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(video.channel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if !video.formattedViews.isEmpty {
                            Text("조회 \(video.formattedViews)").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        if !video.formattedDuration.isEmpty {
                            Text("· \(video.formattedDuration)").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { similarContextMenu(video) }
    }

    @ViewBuilder
    private func similarContextMenu(_ video: TrendingVideo) -> some View {
        Button("재생") { openSimilar(video) }
        Button("다운로드") {
            NotificationCenter.default.post(name: Constants.openDownloaderWindowNotification, object: nil)
        }
        Button("유튜브에서 열기") {
            if let url = URL(string: video.webpageURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func openSimilar(_ video: TrendingVideo) {
        let playerItem = PlayerItem(fileURL: nil, title: video.title, videoId: video.id)
        store.send(.loadVideo(playerItem))
    }

    private func loadSimilarThumbnail(for video: TrendingVideo) {
        guard similarThumbnails[video.id] == nil else { return }
        let service = LibraryCacheService.shared
        Task {
            if let cached = service.cachedThumbnail(for: video.id) {
                await MainActor.run { similarThumbnails[video.id] = cached }
                return
            }
            if let data = await service.loadThumbnail(from: video.thumbnailURL, videoId: video.id),
               let img = NSImage(data: data) {
                await MainActor.run { similarThumbnails[video.id] = img }
            }
        }
    }

    // MARK: - AI Panel (v4.6)

    private var aiPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AI 기능").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { store.send(.toggleAIPanel) } label: {
                    Image(systemName: "xmark").font(.system(size: 11))
                }.buttonStyle(.plain).help("닫기")
            }
            .padding(10)

            Divider()

            if let videoId = store.playerItem.videoId {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        AISummarySection(store: appStore)
                        Divider()
                        AIChapterSection(store: appStore)
                        Divider()
                        AIMindmapSection(store: appStore, videoId: videoId)
                        Divider()
                        AIQnASection(store: appStore)
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 24)).foregroundStyle(.secondary)
                    Text("로컬 파일에서는 AI 기능을 사용할 수 없습니다")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(.regularMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button { store.send(.toggleSubtitleOverlay) } label: {
                Image(systemName: store.showSubtitleOverlay ? "captions.bubble.fill" : "captions.bubble")
            }.help("자막 오버레이")
            Button { store.send(.toggleSubtitlePanel) } label: {
                Image(systemName: store.showSubtitlePanel ? "sidebar.right" : "sidebar.trailing")
            }.help("자막 패널")
            Button { store.send(.toggleQueue) } label: {
                Image(systemName: store.showQueue ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
            }.help("재생 목록")
            Button { store.send(.toggleSimilarVideos) } label: {
                Image(systemName: store.showSimilarVideos ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
            }.help("비슷한 영상")
            Button { store.send(.toggleAIPanel) } label: {
                Image(systemName: "sparkles")
                    .foregroundStyle(store.showAIPanel ? Color.accentColor : Color.primary)
            }.help("AI 기능")
            Spacer()
            Button { store.send(.toggleAlwaysOnTop) } label: {
                Image(systemName: store.isAlwaysOnTop ? "pin.fill" : "pin")
            }.help(store.isAlwaysOnTop ? "최상위 고정 해제" : "항상 최상위로 표시")
            Button(action: toggleFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }.help("전체 화면")
        }
    }

    // MARK: - Up Next

    private var upNextOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
            VStack(spacing: 16) {
                Image(systemName: "play.tv.fill").font(.system(size: 32)).foregroundStyle(.white.opacity(0.6))
                Text("영상이 종료되었습니다").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                if store.autoPlayCountdown > 0, let first = store.recommendations.first {
                    VStack(spacing: 8) {
                        Text("⏭ \(store.autoPlayCountdown)초 후 자동 재생").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                        Button { store.send(.startAutoPlay(first.id)) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "forward.fill")
                                Text("다음 영상: \(first.title)").lineLimit(1)
                            }.font(.system(size: 12)).frame(width: 280)
                        }.buttonStyle(.borderedProminent).tint(.accentColor).controlSize(.small)
                        Button { store.send(.cancelAutoPlay) } label: {
                            Text("취소").font(.system(size: 11))
                        }.buttonStyle(.plain).foregroundColor(.white.opacity(0.6))
                    }
                    if store.recommendations.count > 1 {
                        Divider().background(.white.opacity(0.2)).frame(width: 200)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("더 많은 추천 영상").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                            ForEach(store.recommendations.dropFirst().prefix(2)) { item in
                                Button { store.send(.startAutoPlay(item.id)) } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.circle").font(.system(size: 10))
                                        Text(item.title).font(.system(size: 10)).lineLimit(1)
                                    }.foregroundColor(.white.opacity(0.8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(24)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        let current = isSeeking ? seekTime : mpv.currentTime
        let dur = mpv.duration > 0 ? mpv.duration : store.duration
        let progress = dur > 0 ? min(max(current / dur, 0), 1) : 0
        return HStack(spacing: 8) {
            Button { store.send(.playPrevious) } label: {
                Image(systemName: "backward.end.fill").frame(width: 16).foregroundColor(.white)
            }.buttonStyle(.plain)
                .help(prevQueueTitle.map { "이전: \($0)" } ?? "이전 영상")
                .disabled(!hasPrev)
            Button { mpv.togglePlayPause() } label: {
                Image(systemName: mpv.isPlaying ? "pause.fill" : "play.fill").frame(width: 16).foregroundColor(.white)
            }.buttonStyle(.plain).help(mpv.isPlaying ? "일시 정지" : "재생")
            Button { store.send(.playNext) } label: {
                Image(systemName: "forward.end.fill").frame(width: 16).foregroundColor(.white)
            }.buttonStyle(.plain)
                .help(nextQueueTitle.map { "다음: \($0)" } ?? "다음 영상")
                .disabled(!hasNext)
            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button("\(String(format: "%.2g", rate))x") { store.send(.setPlaybackRate(rate)) }
                }
            } label: {
                Text("\(String(format: "%.2g", store.playbackRate))x").font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.15)))
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("재생 속도")
            Button { store.send(.setALoop(mpv.currentTime)) } label: {
                Text(aLoopText).font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 4).fill(store.aLoop == nil ? .white.opacity(0.15) : .accentColor.opacity(0.85)))
            }.buttonStyle(.plain)
                .help(store.aLoop == nil ? "현재 위치를 반복 시작점(A)으로 설정" : "시작점 갱신: \(timeString(store.aLoop ?? 0))")
            Button { store.send(store.bLoop == nil ? .setBLoop(mpv.currentTime) : .clearABLoop) } label: {
                Text(bLoopText).font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 4).fill(store.bLoop == nil ? .white.opacity(0.15) : .accentColor.opacity(0.85)))
            }.buttonStyle(.plain).disabled(store.aLoop == nil)
                .help(store.bLoop == nil ? "현재 위치를 반복 끝점(B)으로 설정 (A→B 반복 시작)" : "반복 해제")
            Button {
                isRepeatEnabled.toggle()
                mpv.setLoopFile(isRepeatEnabled)
            } label: {
                Image(systemName: "repeat").font(.system(size: 13))
                    .foregroundColor(isRepeatEnabled ? Color.accentColor : .white)
            }.buttonStyle(.plain)
                .help(isRepeatEnabled ? "반복 재생 해제" : "현재 영상 반복 재생")
            Button { store.send(.saveClip) } label: {
                Group {
                    if store.isSavingClip {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: store.lastClipSaved ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 13))
                            .foregroundColor(store.lastClipSaved ? .green : .white)
                    }
                }
                .frame(width: 20)
            }.buttonStyle(.plain)
                .disabled(store.isSavingClip || store.aLoop == nil || store.bLoop == nil || store.playerItem.fileURL == nil)
                .help(store.aLoop != nil && store.bLoop != nil ? "A-B 구간을 클립으로 저장" : "A와 B를 설정하면 클립으로 저장할 수 있어요")
                .popover(isPresented: Binding(
                    get: { store.isSavingClip || store.lastClipSaved },
                    set: { _ in }
                ), arrowEdge: .top) {
                    ClipSavePopoverView(progress: store.clipProgress ?? 1, isComplete: store.lastClipSaved)
                }
            Text(timeString(current)).font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundColor(.white).frame(width: 50, alignment: .trailing)
            Slider(value: Binding(get: { progress }, set: { isSeeking = true; seekTime = $0 * dur }), in: 0...1, onEditingChanged: { editing in
                if !editing { mpv.seek(to: seekTime); isSeeking = false }
            }).disabled(dur <= 0).accentColor(.white)
                .overlay(alignment: .leading) { loopRangeOverlay(dur) }
            Text(timeString(dur)).font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundColor(.white).frame(width: 50, alignment: .leading)
            volumeControl
        }.padding(.horizontal, 12).padding(.vertical, 4)
    }

    private var volumeControl: some View {
        HStack(spacing: 4) {
            Button {
                let target = volume <= 0 ? 100.0 : 0.0
                volume = target
                mpv.setVolume(target)
            } label: {
                Image(systemName: volume <= 0 ? "speaker.slash.fill" : "speaker.fill").font(.system(size: 13)).foregroundColor(.white)
            }.buttonStyle(.plain).help(volume <= 0 ? "음소거 해제" : "음소거")
            Slider(value: Binding(get: { volume }, set: { newVal in volume = newVal; mpv.setVolume(newVal) }), in: 0...100)
                .frame(width: 100).accentColor(.white).help("볼륨")
        }
    }

    // MARK: - Loop / Queue Helpers

    private var hasPrev: Bool { store.queueIndex > 0 && !store.queue.isEmpty }
    private var hasNext: Bool { store.queueIndex >= 0 && store.queueIndex < store.queue.count - 1 }
    private var prevQueueTitle: String? { hasPrev ? store.queue[store.queueIndex - 1].title : nil }
    private var nextQueueTitle: String? { hasNext ? store.queue[store.queueIndex + 1].title : nil }

    private var aLoopText: String {
        guard let a = store.aLoop else { return "A" }
        return "A \(timeString(a))"
    }

    private var bLoopText: String {
        guard let b = store.bLoop else { return "B" }
        return "B \(timeString(b))"
    }

    private func clipMessageBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.75))
        .clipShape(Capsule())
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func loopRangeOverlay(_ dur: Double) -> some View {
        if let a = store.aLoop, let b = store.bLoop, dur > 0, a < b {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: max((b - a) / dur * geo.size.width, 4), height: 3)
                        .offset(x: a / dur * geo.size.width)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Queue Panel

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("재생 목록").font(.headline)
                Spacer()
                if store.queueIndex >= 0 {
                    Text("\(store.queueIndex + 1)/\(store.queue.count)").font(.caption).foregroundColor(.secondary)
                }
            }.padding(.horizontal, 12).padding(.vertical, 10)
            Divider()
            if store.queue.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet").font(.title2).foregroundColor(.secondary)
                    Text("재생 목록이 비어 있습니다.\n보관함에서 영상을 열면 목록에 추가됩니다.").font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, item in
                            Button { store.send(.playAtQueue(index)) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: index == store.queueIndex ? "play.fill" : "play")
                                        .font(.system(size: 10)).foregroundColor(index == store.queueIndex ? .accentColor : .secondary)
                                        .frame(width: 14)
                                    Text(item.title)
                                        .lineLimit(1).font(.system(size: 12))
                                        .foregroundColor(index == store.queueIndex ? .primary : .secondary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(index == store.queueIndex ? Color.accentColor.opacity(0.14) : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(item.title)
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Actions

    private func setupPlayer() {
        guard mpv.isRenderReady else { return }
        let seekTime = store.playerItem.initialSeekTime
        if let fileURL = store.playerItem.fileURL {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { store.send(.fileMissing); return }
            mpv.loadFile(fileURL, startTime: seekTime)
        } else if let streamURL = store.streamURL {
            mpv.loadStream(streamURL, startTime: seekTime)
        }
    }

    private func toggleFullscreen() {
        if let window { window.toggleFullScreen(nil) }
        else if let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.identifier?.rawValue == "player" }) {
            window = win; win.toggleFullScreen(nil)
        }
    }
}

// MARK: - Clip Save Popover

struct ClipSavePopoverView: View {
    let progress: Double
    let isComplete: Bool
    @State private var elapsed: TimeInterval = 0
    @State private var startTime = Date()
    @State private var animProgress: Double = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "scissors")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isComplete ? .green : Color.accentColor)
                Text(isComplete ? "클립 저장 완료" : "클립 저장 중...")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int((isComplete ? 1 : animProgress) * 100))%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
            }
            ProgressView(value: isComplete ? 1 : animProgress)
                .controlSize(.small)
            HStack {
                Text(isComplete ? "클립이 보관함에 저장되었습니다" : "경과 \(formatTime(elapsed))")
                Spacer()
                if !isComplete, let remaining = remainingTime {
                    Text("남은 시간 약 \(formatTime(remaining))")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            if !isComplete {
                Text("저장 중에도 영상은 계속 시청할 수 있어요")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(width: 250)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animProgress = progress }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) { animProgress = newValue }
        }
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(startTime)
        }
    }

    private var remainingTime: TimeInterval? {
        guard progress > 0.03, elapsed > 1 else { return nil }
        let total = elapsed / progress
        return max(total - elapsed, 0)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
