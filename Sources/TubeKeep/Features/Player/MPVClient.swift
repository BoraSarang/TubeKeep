import Foundation
import Combine
import AppKit
import CoreVideo
import Clibmpv

private func CGLGetProcAddress(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    dlsym(UnsafeMutableRawPointer(bitPattern: -2), name)
}

final class MPVClient: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoaded = false
    @Published var isFinished = false
    @Published var hasVideo = false
    @Published var isRenderReady = false
    @Published var error: String?

    private var mpv: OpaquePointer?
    private var renderContext: OpaquePointer?
    private var displayLink: CVDisplayLink?
    private var glContext: NSOpenGLContext?
    private weak var renderView: MPVOpenGLView?
    private let renderQueue = DispatchQueue(label: "com.borasarang.mpv.render", qos: .userInteractive)
    private var playbackStart: Date?
    private var firstFrameLogged = false
    private var pendingSeekTime: Double?
    private var loopA: Double?
    private var loopB: Double?
    private var renderCallbackLogCount = 0
    private var isFullscreenTransition = false
    private var isWindowResizing = false
    private let transitionLock = NSLock()
    private var fullscreenObservers: [NSObjectProtocol] = []

    init() {
        setupMPV()
        setupFullscreenObservers()
    }

    deinit {
        fullscreenObservers.forEach { NotificationCenter.default.removeObserver($0) }
        stopDisplayLink()
        renderQueue.sync {}
        if let rc = renderContext { mpv_render_context_free(rc) }
        renderContext = nil
        if let h = mpv { mpv_terminate_destroy(h) }
        mpv = nil
    }

    // MARK: - Setup

    private func setupMPV() {
        let h = mpv_create()
        guard let h else { error = "mpv_create failed"; return }

        mpv_set_option_string(h, "vo", "libmpv")
        mpv_set_option_string(h, "hwdec", "no")
        mpv_set_option_string(h, "volume", "100")
        mpv_set_option_string(h, "cache", "yes")
        mpv_set_option_string(h, "keepaspect", "yes")

        if mpv_initialize(h) < 0 {
            error = "mpv_initialize failed"
            mpv_terminate_destroy(h)
            return
        }

        mpv_observe_property(h, 0, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(h, 0, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(h, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(h, 0, "eof-reached", MPV_FORMAT_FLAG)
        mpv_observe_property(h, 0, "height", MPV_FORMAT_INT64)

        mpv_set_wakeup_callback(h, Self.wakeupCb, Unmanaged.passUnretained(self).toOpaque())
        mpv_request_log_messages(h, "info")

        mpv = h
    }

    func attachView(_ view: MPVOpenGLView) {
        renderView = view
        guard let ctx = view.openGLContext else { return }
        glContext = ctx
        DispatchQueue.main.async { [weak self] in
            self?.setupOpenGL()
        }
    }

    /// fullscreen 진입/종료 전환 중에는 GL 컨텍스트가 재구성되는 순간이라
    /// displayLink 렌더링을 잠시 중단한다 (glBlit/CGLSetVirtualScreen 크래시 방지).
    /// 창 live resize 중에도 drawable이 재구성되므로 동일하게 렌더링을 중단한다.
    private func setupFullscreenObservers() {
        let center = NotificationCenter.default
        fullscreenObservers.append(center.addObserver(forName: NSWindow.willEnterFullScreenNotification, object: nil, queue: .main) { [weak self] note in
            self?.setFullscreenTransition(note, transitioning: true)
        })
        fullscreenObservers.append(center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: nil, queue: .main) { [weak self] note in
            self?.setFullscreenTransition(note, transitioning: false)
        })
        fullscreenObservers.append(center.addObserver(forName: NSWindow.willExitFullScreenNotification, object: nil, queue: .main) { [weak self] note in
            self?.setFullscreenTransition(note, transitioning: true)
        })
        fullscreenObservers.append(center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: nil, queue: .main) { [weak self] note in
            self?.setFullscreenTransition(note, transitioning: false)
        })
        fullscreenObservers.append(center.addObserver(forName: NSWindow.willStartLiveResizeNotification, object: nil, queue: .main) { [weak self] note in
            self?.setWindowResizing(note, resizing: true)
        })
        fullscreenObservers.append(center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: nil, queue: .main) { [weak self] note in
            self?.setWindowResizing(note, resizing: false)
        })
    }

    private func setWindowResizing(_ note: Notification, resizing: Bool) {
        guard let window = note.object as? NSWindow else { return }
        if let renderWindow = renderView?.window, renderWindow !== window { return }
        transitionLock.lock()
        isWindowResizing = resizing
        transitionLock.unlock()
    }

    private func setFullscreenTransition(_ note: Notification, transitioning: Bool) {
        guard let window = note.object as? NSWindow else { return }
        // fullscreen 전환 중에는 뷰가 윈도우에서 잠시 분리되어 renderView.window가 nil이 될 수 있다.
        // 플레이어 윈도우가 아님을 확실히 알 수 있을 때만 무시한다.
        if let renderWindow = renderView?.window, renderWindow !== window { return }
        transitionLock.lock()
        isFullscreenTransition = transitioning
        transitionLock.unlock()
        #if DEBUG
        DebugLogManager.shared?.append("[mpv] fullscreen transition=\(transitioning)")
        #endif
    }

    private func setupOpenGL() {
        // view가 재생성되어 attachView → setupOpenGL이 중복 호출되더라도
        // 이미 생성된 렌더 컨텍스트는 재생성하지 않는다(중복 create 시 -20 "already set").
        if isRenderReady, renderContext != nil { return }
        guard let view = renderView, let glCtx = view.openGLContext else {
            DebugLogManager.shared?.append("[mpv] FAIL: no OpenGL context")
            return
        }
        glContext = glCtx
        glCtx.makeCurrentContext()

        guard let mpv else { return }

        let getProc: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? = { _, name in
            guard let name else { return nil }
            return CGLGetProcAddress(name)
        }
        var initParams = mpv_opengl_init_params(get_proc_address: getProc, get_proc_address_ctx: nil)

        var apiType = MPV_RENDER_API_TYPE_OPENGL
        var renderParams: [mpv_render_param] = [
            mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: &apiType),
            mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: &initParams),
            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
        ]

        var rc: OpaquePointer?
        let result = mpv_render_context_create(&rc, mpv, &renderParams)
        guard result >= 0, let rc else {
            DebugLogManager.shared?.append("[mpv] FAIL: mpv_render_context_create returned \(result)")
            error = "mpv_render_context_create failed"
            isRenderReady = false
            return
        }
        renderContext = rc
        mpv_render_context_set_update_callback(rc, Self.renderCb, Unmanaged.passUnretained(self).toOpaque())

        isRenderReady = true
        setupDisplayLink()
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { return }
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputHandler(displayLink) { _, _, _, _, _ -> CVReturn in
            let client = Unmanaged<MPVClient>.fromOpaque(ctx).takeUnretainedValue()
            client.renderQueue.async { client.renderFrame() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(displayLink)
    }

    private func stopDisplayLink() {
        guard let dl = displayLink else { return }
        CVDisplayLinkStop(dl)
        displayLink = nil
    }

    // MARK: - Rendering

    private func renderFrame() {
        guard let ctx = renderContext, let view = renderView else { return }
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        // 창이 사라진 뒤(윈도우 닫힘/재생성 중) GL 컨텍스트가 무효한 시점의 렌더링을 차단 — glBlit 크래시 방지
        guard let window = view.window, window.screen != nil else { return }
        transitionLock.lock()
        let transitioning = isFullscreenTransition
        let resizing = isWindowResizing
        transitionLock.unlock()
        // fullscreen 전환 중 + 창 리사이즈 중에는 drawable이 재구성되는 시점이라 렌더를 건너뛴다.
        guard !transitioning, !resizing else { return }
        guard let glCtx = view.openGLContext else { return }
        glContext = glCtx
        let scale = view.window?.backingScaleFactor ?? 2
        let w = Int32(view.bounds.width * scale)
        let h = Int32(view.bounds.height * scale)

        // NSOpenGLContext는 스레드 안전하지 않다. 메인 스레드의 reshape/update(drawable 재구성)와
        // 이 렌더 스레드의 glBlit이 겹치면 AppleMetalOpenGLRenderer 내부에서 해제된 텍스처를 참조해
        // SIGSEGV가 발생하므로 CGL 잠금으로 직렬화한다. (T-1206)
        glCtx.lock()
        glCtx.makeCurrentContext()

        var fbo = mpv_opengl_fbo(fbo: 0, w: w, h: h, internal_format: 0)
        var flip: Int32 = 1

        var params: [mpv_render_param] = [
            mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: &fbo),
            mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: &flip),
            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
        ]
        let result = mpv_render_context_render(ctx, &params)
        if result < 0 { DebugLogManager.shared?.append("[mpv] render error: \(result)") }
        mpv_render_context_report_swap(ctx)
        glCtx.flushBuffer()
        glCtx.unlock()

        if !firstFrameLogged, let start = playbackStart {
            firstFrameLogged = true
            let elapsed = Date().timeIntervalSince(start) * 1000
            DebugLogManager.shared?.push(.PERF, category: "Player", message: "첫 프레임 렌더링", meta: ["elapsed_ms": Int(elapsed)])
        }
    }

    // MARK: - Callbacks

    private static let wakeupCb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { ctx in
        guard let ctx else { return }
        let client = Unmanaged<MPVClient>.fromOpaque(ctx).takeUnretainedValue()
        DispatchQueue.main.async { client.readEvents() }
    }

    private static let renderCb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { ctx in
        guard let ctx else { return }
        let client = Unmanaged<MPVClient>.fromOpaque(ctx).takeUnretainedValue()
        client.renderQueue.async {
            guard let rc = client.renderContext else { return }
            let flags = mpv_render_context_update(rc)
            if client.renderCallbackLogCount < 5 {
                client.renderCallbackLogCount += 1
                #if DEBUG
                Task { @MainActor in DebugLogManager.shared?.append("[mpv] renderCb flags=\(flags)") }
                #endif
            }
            if flags & UInt64(MPV_RENDER_UPDATE_FRAME.rawValue) != 0 {
                client.renderFrame()
            }
        }
    }

    private func readEvents() {
        guard let mpv else { return }
        while true {
            let event = mpv_wait_event(mpv, 0)
            guard let event, event.pointee.event_id != MPV_EVENT_NONE else { break }
            handleEvent(event.pointee)
        }
    }

    private func handleEvent(_ event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_LOG_MESSAGE:
            guard let data = event.data else { return }
            let msg = data.assumingMemoryBound(to: mpv_event_log_message.self).pointee
            let prefix = String(cString: msg.prefix)
            let text = String(cString: msg.text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            #if DEBUG
            Task { @MainActor in DebugLogManager.shared?.append("[mpv][\(prefix)] \(text)") }
            #endif
        case MPV_EVENT_FILE_LOADED:
            #if DEBUG
            Task { @MainActor in DebugLogManager.shared?.append("[mpv] FILE_LOADED") }
            #endif
            runOnMain {
                self.isLoaded = true
                if let pendingSeekTime = self.pendingSeekTime {
                    self.seek(to: pendingSeekTime)
                    self.pendingSeekTime = nil
                    self.play()
                }
            }
        case MPV_EVENT_END_FILE:
            guard let data = event.data else { return }
            let endFile = data.assumingMemoryBound(to: mpv_event_end_file.self).pointee
            #if DEBUG
            Task { @MainActor in DebugLogManager.shared?.append("[mpv] END_FILE reason=\(endFile.reason.rawValue)") }
            #endif
            if endFile.reason == MPV_END_FILE_REASON_EOF {
                runOnMain { self.isFinished = true }
            } else if endFile.reason == MPV_END_FILE_REASON_ERROR {
                runOnMain { self.error = "재생 오류가 발생했습니다" }
            }
        case MPV_EVENT_PROPERTY_CHANGE:
            guard let propPtr = event.data else { return }
            let prop = propPtr.assumingMemoryBound(to: mpv_event_property.self).pointee
            let name = String(cString: prop.name)
            switch name {
            case "time-pos":
                if prop.format == MPV_FORMAT_DOUBLE {
                    let val = prop.data?.assumingMemoryBound(to: Double.self).pointee ?? 0
                    runOnMain { [self] in
                        self.currentTime = val
                        checkABLoop(at: val)
                    }
                }
            case "duration":
                if prop.format == MPV_FORMAT_DOUBLE {
                    let val = prop.data?.assumingMemoryBound(to: Double.self).pointee ?? 0
                    runOnMain { self.duration = val }
                }
            case "pause":
                if prop.format == MPV_FORMAT_FLAG {
                    let val = prop.data?.assumingMemoryBound(to: Int32.self).pointee ?? 1
                    runOnMain { self.isPlaying = val == 0 }
                }
            case "eof-reached":
                if prop.format == MPV_FORMAT_FLAG {
                    let val = prop.data?.assumingMemoryBound(to: Int32.self).pointee ?? 0
                    if val != 0 { runOnMain { self.isFinished = true } }
                }
            case "height":
                if prop.format == MPV_FORMAT_INT64 {
                    let val = prop.data?.assumingMemoryBound(to: Int64.self).pointee ?? 0
                    runOnMain { self.hasVideo = val > 0 }
                    #if DEBUG
                    Task { @MainActor in DebugLogManager.shared?.append("[mpv] video height=\(val)") }
                    #endif
                }
            default: break
            }
        default: break
        }
    }

    // MARK: - Public API

    func loadFile(_ url: URL, startTime: Double? = nil) {
        guard let mpv else { return }
        runOnMain { [self] in resetState() }
        playbackStart = Date()
        firstFrameLogged = false
        #if DEBUG
        DebugLogManager.shared?.append("[mpv] loadfile(file): \(url.lastPathComponent)")
        #endif
        pendingSeekTime = nil
        if let startTime, startTime > 0 {
            // mpv 네이티브 start 옵션: 로드 시점부터 해당 위치에서 시작. "+NNN"은 상대시간으로 해석되므로 절대 초만 전달한다.
            mpv_set_property_string(mpv, "start", "\(Int(startTime))")
        } else {
            mpv_set_property_string(mpv, "start", "0")
        }
        mpvCommand(mpv, args: ["loadfile", url.path])
    }

    func loadStream(_ url: URL, startTime: Double? = nil) {
        guard let mpv else { return }
        runOnMain { [self] in resetState() }
        playbackStart = Date()
        firstFrameLogged = false
        #if DEBUG
        DebugLogManager.shared?.append("[mpv] loadfile(stream): \(url.absoluteString.prefix(80))")
        #endif
        pendingSeekTime = nil
        if let startTime, startTime > 0 {
            mpv_set_property_string(mpv, "start", "\(Int(startTime))")
        } else {
            mpv_set_property_string(mpv, "start", "0")
        }
        mpvCommand(mpv, args: ["loadfile", url.absoluteString])
    }

    func play() {
        guard let mpv else { return }
        mpv_set_property_string(mpv, "pause", "no")
    }

    func pause() {
        guard let mpv else { return }
        mpv_set_property_string(mpv, "pause", "yes")
    }

    func togglePlayPause() {
        guard let mpv else { return }
        mpvCommand(mpv, args: ["cycle", "pause"])
    }

    func seek(to time: Double) {
        guard let mpv else { return }
        var t = time
        mpv_set_property(mpv, "time-pos", MPV_FORMAT_DOUBLE, &t)
    }

    func seekAfterLoad(_ time: Double) {
        pendingSeekTime = time
        if isLoaded {
            seek(to: time)
            pendingSeekTime = nil
        }
    }

    func seekRelative(_ seconds: Double) {
        guard let mpv else { return }
        mpvCommand(mpv, args: ["seek", String(format: "%.1f", seconds), "relative"])
    }

    func setVolume(_ vol: Double) {
        guard let mpv else { return }
        var v = max(0, min(200, vol))
        mpv_set_property(mpv, "volume", MPV_FORMAT_DOUBLE, &v)
    }

    func setPlaybackRate(_ rate: Double) {
        guard let mpv else { return }
        var r = max(0.25, min(4.0, rate))
        mpv_set_property(mpv, "speed", MPV_FORMAT_DOUBLE, &r)
    }

    func setLoopFile(_ enabled: Bool) {
        guard let mpv else { return }
        mpv_set_property_string(mpv, "loop-file", enabled ? "inf" : "no")
    }

    func setALoop(at time: Double) {
        loopA = time
        if let b = loopB, b <= time { loopB = nil }
    }

    func setBLoop(at time: Double) {
        guard loopA != nil else { return }
        loopB = time
    }

    func clearABLoop() {
        loopA = nil
        loopB = nil
    }

    func stop() {
        guard let mpv else { return }
        mpvCommand(mpv, args: ["stop"])
        runOnMain { [self] in
            isLoaded = false
            isFinished = false
            currentTime = 0
        }
    }

    private func resetState() {
        isLoaded = false
        isFinished = false
        error = nil
        currentTime = 0
        duration = 0
        pendingSeekTime = nil
        loopA = nil
        loopB = nil
    }

    private func checkABLoop(at time: Double) {
        guard let a = loopA, let b = loopB, b > a else { return }
        if time >= b { seek(to: a) }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}

private func mpvCommand(_ handle: OpaquePointer, args: [String]) {
    var cstrs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
    cstrs.append(nil)
    let result = cstrs.withUnsafeMutableBufferPointer { buf in
        let ptr = unsafeBitCast(buf.baseAddress, to: UnsafeMutablePointer<UnsafePointer<CChar>?>?.self)
        return mpv_command(handle, ptr)
    }
    cstrs.compactMap { $0 }.forEach { free($0) }
    if result < 0 { DebugLogManager.shared?.append("[mpv] command failed: \(args.first ?? "?")") }
}
