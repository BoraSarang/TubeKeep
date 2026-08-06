import SwiftUI
import ComposableArchitecture

struct PlayerView: View {
    let store: StoreOf<PlayerReducer>
    @StateObject private var mpv = MPVClient()
    @State private var window: NSWindow?
    @State private var volume: Double = 100
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    @State private var showControls = false
    @State private var controlsTask: Task<Void, Never>?

    private let videoWidth: CGFloat = 854
    private let videoHeight: CGFloat = 480
    private let controlBarHeight: CGFloat = 44
    private let panelWidth: CGFloat = 320
    private let controlsAutoHideDelay: Duration = .seconds(3)

    private var windowWidth: CGFloat { videoWidth + (store.showQueue || store.showSubtitlePanel ? panelWidth : 0) }
    private var windowHeight: CGFloat { videoHeight }

    var body: some View {
        HStack(spacing: 0) {
            videoArea
            if store.showQueue {
                queuePanel
                    .frame(width: panelWidth)
            } else if store.showSubtitlePanel {
                subtitlePanel
                    .frame(width: panelWidth)
            }
        }
        .frame(minWidth: windowWidth, maxWidth: .infinity, minHeight: windowHeight, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alwaysOnTop(store.isAlwaysOnTop, windowIdentifier: "player")
        .toolbar { toolbarContent }
        .onDisappear { mpv.stop() }
        .onChange(of: mpv.isRenderReady) { _, ready in if ready { setupPlayer() } }
        .onChange(of: store.playerItemId) { _, _ in mpv.stop(); setupPlayer() }
        .onChange(of: store.streamURL) { _, newURL in
            if newURL != nil, store.playerItem.fileURL == nil { mpv.stop(); setupPlayer() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notif in
            if (notif.object as? NSWindow) == window { mpv.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.playerSeekNotification)) { notif in
            guard let direction = notif.userInfo?["direction"] as? Double else { return }
            let step = Settings.loadSettings().seekStepSeconds
            mpv.seekRelative(direction * step)
        }
        .onChange(of: store.showSubtitlePanel) { _, _ in
            window?.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        }
        .onChange(of: store.showQueue) { _, _ in
            window?.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        }
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
        .background(WindowAccessor { win in DispatchQueue.main.async { window = win } })
    }

    // MARK: - Video Area

    private var videoArea: some View {
        ZStack {
            Color.black
            if store.isStreamLoading {
                loadingView
            } else {
                playbackView
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
                if showControls { controlBar.frame(height: controlBarHeight).background(.ultraThinMaterial).transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            if showControls { fullscreenButton.transition(.opacity) }
        }
        .frame(minWidth: videoWidth, maxWidth: .infinity, minHeight: videoHeight, maxHeight: .infinity)
        .clipped()
        .onTapGesture(count: 1) { store.send(.toggleSubtitleOverlay) }
        .onTapGesture(count: 2) { toggleFullscreen() }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                showControls = true
                controlsTask?.cancel()
                controlsTask = Task {
                    try? await Task.sleep(for: controlsAutoHideDelay)
                    guard !Task.isCancelled else { return }
                    if store.isSavingClip { return }
                    await MainActor.run { showControls = false }
                }
            case .ended:
                showControls = false
                controlsTask?.cancel()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.5)
            Text("스트리밍 URL을 가져오는 중...").font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
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
            isLoading: store.subtitleLoading,
            subtitleAvailable: store.subtitleAvailable,
            errorMessage: store.subtitleError,
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
            Spacer()
            Button { store.send(.toggleAlwaysOnTop) } label: {
                Image(systemName: store.isAlwaysOnTop ? "pin.fill" : "pin")
            }.help(store.isAlwaysOnTop ? "최상위 고정 해제" : "항상 최상위로 표시")
            Button(action: toggleFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }.help("전체 화면")
            Button { mpv.stop(); window?.close() } label: {
                Image(systemName: "xmark.circle")
            }.help("창 닫기")
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
        if let fileURL = store.playerItem.fileURL {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { store.send(.fileMissing); return }
            mpv.loadFile(fileURL)
        } else if let streamURL = store.streamURL {
            mpv.loadStream(streamURL)
        }
        if let seekTime = store.playerItem.initialSeekTime, seekTime > 0 {
            mpv.seekAfterLoad(seekTime)
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
