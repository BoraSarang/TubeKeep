import SwiftUI
import AVKit
import ComposableArchitecture
import CryptoKit

struct PlayerView: View {
    let store: StoreOf<PlayerReducer>
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var window: NSWindow?
    @State private var isPlaying = false
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    @State private var showControls = false
    @State private var controlsTask: Task<Void, Never>?

    private let videoWidth: CGFloat = 854
    private let videoHeight: CGFloat = 480
    private let controlBarHeight: CGFloat = 44
    private let panelWidth: CGFloat = 320
    private let controlsAutoHideDelay: Duration = .seconds(3)

    private var windowWidth: CGFloat {
        videoWidth + (store.showSubtitlePanel ? panelWidth : 0)
    }

    private var windowHeight: CGFloat {
        videoHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color.black
                if let player {
                    NSPlayerView(player: player)
                }
                if store.isConverting {
                    VStack(spacing: 8) {
                        ProgressView(value: store.conversionProgress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .frame(width: 240)
                        Text("\(Int(store.conversionProgress * 100))% 변환 중...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        if !store.conversionETA.isEmpty {
                            Text("남은 시간: \(store.conversionETA)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                if store.showSubtitleOverlay {
                    SubtitleOverlay(
                        cues: store.subtitles,
                        currentTime: store.currentTime
                    )
                }

                VStack {
                    Spacer()
                    if showControls {
                        controlBar
                            .frame(height: controlBarHeight)
                            .background(.ultraThinMaterial)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                if showControls {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                toggleFullscreen()
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .help("전체 화면")
                            .padding(8)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
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
                        await MainActor.run { showControls = false }
                    }
                case .ended:
                    showControls = false
                    controlsTask?.cancel()
                }
            }

            if store.showSubtitlePanel {
                let hasLocalFile = store.playerItem.fileURL != nil
                SubtitlePanel(
                    cues: store.subtitles,
                    currentTime: store.currentTime,
                    isLoading: store.subtitleLoading,
                    subtitleAvailable: store.subtitleAvailable,
                    errorMessage: store.subtitleError,
                    isTranscribing: store.isTranscribing,
                    transcribeError: store.transcribeError,
                    whisperProgressMessage: store.whisperProgressMessage,
                    onSeek: { time in player?.seek(to: CMTime(seconds: time, preferredTimescale: 600)) },
                    onDownloadSubtitles: store.playerItem.videoId != nil ? { store.send(.downloadSubtitles) } : nil,
                    onTranscribe: hasLocalFile ? { store.send(.transcribeWithWhisper) } : nil,
                    onDeleteSubtitles: store.playerItem.videoId != nil ? { store.send(.deleteSubtitles) } : nil,
                    onOpenWhisperSettings: {
                        NotificationCenter.default.post(name: Constants.openWhisperSettingsNotification, object: nil)
                    }
                )
                .frame(width: panelWidth)
            }
        }
        .frame(minWidth: windowWidth, maxWidth: .infinity, minHeight: windowHeight, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alwaysOnTop(store.isAlwaysOnTop, windowIdentifier: "player")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.send(.toggleSubtitleOverlay)
                } label: {
                    Image(systemName: store.showSubtitleOverlay ? "captions.bubble.fill" : "captions.bubble")
                }
                .help("자막 오버레이")

                Button {
                    store.send(.toggleSubtitlePanel)
                } label: {
                    Image(systemName: store.showSubtitlePanel ? "sidebar.right" : "sidebar.trailing")
                }
                .help("자막 패널")

                Spacer()

                Button {
                    store.send(.toggleAlwaysOnTop)
                } label: {
                    Image(systemName: store.isAlwaysOnTop ? "pin.fill" : "pin")
                }
                .help(store.isAlwaysOnTop ? "최상위 고정 해제" : "항상 최상위로 표시")

                Button(action: toggleFullscreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("전체 화면")

                Button {
                    cleanupPlayer()
                    window?.close()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("창 닫기")
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closedWindow = notification.object as? NSWindow,
                  closedWindow == window else { return }
            cleanupPlayer()
        }
        .onChange(of: store.showSubtitlePanel) { _, _ in
            guard let window else { return }
            let width = videoWidth + (store.showSubtitlePanel ? panelWidth : 0)
            let size = NSSize(width: width, height: windowHeight)
            window.setContentSize(size)
        }
        .onReceive(NotificationCenter.default.publisher(for: .seekToTime)) { notification in
            if let time = notification.object as? Double {
                player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
            }
        }
        .background(
            WindowAccessor { win in
                DispatchQueue.main.async {
                    window = win
                }
            }
        )
    }

    private var controlBar: some View {
        let current = isSeeking ? seekTime : store.currentTime
        let duration = store.duration
        let progress = duration > 0 ? min(max(current / duration, 0), 1) : 0

        return HStack(spacing: 8) {
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 16)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(store.isConverting)
            .help(isPlaying ? "일시 정지" : "재생")

            Text(timeString(current))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { progress },
                    set: { newValue in
                        isSeeking = true
                        seekTime = newValue * duration
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing {
                        let time = seekTime
                        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
                        isSeeking = false
                    }
                }
            )
            .disabled(store.isConverting || duration <= 0)
            .accentColor(.white)

            Text(timeString(duration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 50, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func setupPlayer() {
        guard let url = store.playerItem.fileURL ?? store.playerItem.streamURL else {
            print("[Player] no URL: fileURL=\(String(describing: store.playerItem.fileURL)) streamURL=\(String(describing: store.playerItem.streamURL))")
            return
        }
        print("[Player] loading: \(url)")

        if let fileURL = store.playerItem.fileURL {
            let playerItem = AVPlayerItem(url: fileURL)
            let avPlayer = AVPlayer(playerItem: playerItem)
            setupPlayer(with: avPlayer)
            print("[Player] playback started, checking codec async...")

            Task { [self] in
                guard await needsTranscoding(url: fileURL) else { return }

                print("[Player] unsupported codec, checking cache for transcoding...")
                let cacheKey = transcodeCacheKey(for: fileURL)
                let cachedURL = Constants.transcodedCacheDirectory.appendingPathComponent("\(cacheKey).mp4")
                if FileManager.default.fileExists(atPath: cachedURL.path) {
                    print("[Player] cache hit, replacing player: \(cachedURL.path)")
                    let item = AVPlayerItem(url: cachedURL)
                    avPlayer.replaceCurrentItem(with: item)
                    avPlayer.play()
                    return
                }

                transcodeAndPlay(fileURL, player: avPlayer)
            }
        } else if let streamURL = store.playerItem.streamURL {
            let playerItem = AVPlayerItem(url: streamURL)
            let avPlayer = AVPlayer(playerItem: playerItem)
            setupPlayer(with: avPlayer)
        }
    }

    private static var codecCache: [String: Bool] {
        get { UserDefaults.standard.dictionary(forKey: "PlayerCodecCache") as? [String: Bool] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "PlayerCodecCache") }
    }

    private func needsTranscoding(url: URL) async -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return false }
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let modDate = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let cacheKey = "\(url.path)::\(modDate)"
        if let cached = Self.codecCache[cacheKey] { return cached }

        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video),
              let track = tracks.first,
              let fmtDesc = (try? await track.load(.formatDescriptions))?.first
        else { return false }

        let codecType = CMFormatDescriptionGetMediaSubType(fmtDesc)
        let unsupported: Set<UInt32> = [
            0x61763031, // 'av01' — AV1
            0x76703039, // 'vp09' — VP9
            0x76703038, // 'vp08' — VP8
        ]
        let result = unsupported.contains(codecType)
        print("[Player] codec: \(String(format: "%c%c%c%c", (codecType>>24)&0xFF, (codecType>>16)&0xFF, (codecType>>8)&0xFF, codecType&0xFF)) needsTranscoding=\(result)")
        Self.codecCache[cacheKey] = result
        return result
    }

    private func getDuration(url: URL) -> Double {
        let fm = FileManager.default
        let outURL = fm.temporaryDirectory.appendingPathComponent("ffprobe_dur_\(UUID().uuidString).log")
        fm.createFile(atPath: outURL.path, contents: nil)
        defer { try? fm.removeItem(at: outURL) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.ffprobePath)
        process.arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=nokey=1:noprint_wrappers=1",
            url.path,
        ]
        let outHandle = try? FileHandle(forWritingTo: outURL)
        process.standardOutput = outHandle ?? FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            try? outHandle?.close()
            return Double((try? String(contentsOf: outURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
        } catch {
            return 0
        }
    }

    private func transcodeCacheKey(for source: URL) -> String {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: source.path)
        let fileSize = (attrs?[.size] as? UInt64) ?? 0
        let modDate = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let raw = "\(source.path)::\(fileSize)::\(modDate)"
        return raw.data(using: .utf8).map { d in
            SHA256.hash(data: d).compactMap { String(format: "%02x", $0) }.joined()
        } ?? UUID().uuidString
    }

    private func transcodeAndPlay(_ source: URL, player existingPlayer: AVPlayer? = nil) {
        let fm = FileManager.default
        let cacheKey = transcodeCacheKey(for: source)
        let cachedURL = Constants.transcodedCacheDirectory.appendingPathComponent("\(cacheKey).mp4")

        if fm.fileExists(atPath: cachedURL.path) {
            print("[Player] cache hit: \(cachedURL.path)")
            if let existingPlayer {
                existingPlayer.replaceCurrentItem(with: AVPlayerItem(url: cachedURL))
                existingPlayer.play()
            } else {
                let item = AVPlayerItem(url: cachedURL)
                let avPlayer = AVPlayer(playerItem: item)
                setupPlayer(with: avPlayer)
            }
            return
        }

        let totalDuration = getDuration(url: source)
        print("[Player] source duration: \(totalDuration)s")

        print("[Player] cache miss, transcoding: \(source.path) -> \(cachedURL.path)")
        store.send(.setConverting(true))
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Constants.ffmpegPath)
            process.arguments = ["-i", source.path, "-c:v", "libx264", "-preset", "fast", "-c:a", "aac", "-progress", "pipe:1", "-y", cachedURL.path]

            let progressPipe = Pipe()
            process.standardOutput = progressPipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()

                let fh = progressPipe.fileHandleForReading
                fh.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                    for part in line.components(separatedBy: "\n") {
                        if part.hasPrefix("out_time_us=") {
                            let us = Double(part.dropFirst(12).trimmingCharacters(in: .whitespaces)) ?? 0
                            let elapsed = us / 1_000_000
                            if totalDuration > 0 {
                                let progress = min(max(elapsed / totalDuration, 0), 1)
                                DispatchQueue.main.async {
                                    store.send(.updateConversionProgress(progress))
                                }
                            }
                        }
                        if part.hasPrefix("speed=") {
                            let speedStr = part.dropFirst(6).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "x", with: "")
                            if let speed = Double(speedStr), speed > 0, totalDuration > 0, let currentProgress = store.conversionProgress as Double?, currentProgress > 0 {
                                let remaining = (1 - currentProgress) * totalDuration / speed
                                let etaStr = timeString(remaining)
                                DispatchQueue.main.async {
                                    store.send(.updateConversionETA(etaStr))
                                }
                            }
                        }
                    }
                }

                process.waitUntilExit()
                fh.readabilityHandler = nil
            } catch {
                print("[Player] transcode error: \(error)")
            }
            let success = process.terminationStatus == 0
            DispatchQueue.main.async { [self] in
                store.send(.setConverting(false))
                if success {
                    if let existingPlayer {
                        existingPlayer.replaceCurrentItem(with: AVPlayerItem(url: cachedURL))
                        existingPlayer.play()
                    } else {
                        let item = AVPlayerItem(url: cachedURL)
                        let avPlayer = AVPlayer(playerItem: item)
                        setupPlayer(with: avPlayer)
                    }
                } else {
                    print("[Player] transcode failed, trying original")
                    try? fm.removeItem(at: cachedURL)
                    if let existingPlayer {
                        existingPlayer.replaceCurrentItem(with: AVPlayerItem(url: source))
                        existingPlayer.play()
                    } else {
                        let item = AVPlayerItem(url: source)
                        let avPlayer = AVPlayer(playerItem: item)
                        setupPlayer(with: avPlayer)
                    }
                }
            }
        }
    }

    private func setupPlayer(with avPlayer: AVPlayer) {
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [store, weak avPlayer] time in
            store.send(.timeUpdated(time.seconds))
            if !isSeeking, let avPlayer {
                isPlaying = avPlayer.timeControlStatus == .playing
            }
        }

        if store.playerItem.duration > 0 {
            store.send(.durationUpdated(store.playerItem.duration))
        } else {
            Task { [store] in
                if let duration = try? await avPlayer.currentItem?.asset.load(.duration).seconds {
                    _ = await MainActor.run {
                        store.send(.durationUpdated(duration))
                    }
                }
            }
        }

        player = avPlayer
        DispatchQueue.main.async { [weak avPlayer] in
            guard let avPlayer else { return }
            avPlayer.play()
            isPlaying = true
        }
    }

    private func cleanupPlayer() {
        if let observer = timeObserver, let avPlayer = player {
            avPlayer.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        timeObserver = nil
    }

    private func toggleFullscreen() {
        if let window {
            window.toggleFullScreen(nil)
        } else if let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.identifier?.rawValue == "player" }) {
            window = win
            win.toggleFullScreen(nil)
        }
    }
}
