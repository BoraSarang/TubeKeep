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
    private weak var renderView: NSView?
    private let renderQueue = DispatchQueue(label: "com.borasarang.mpv.render", qos: .userInteractive)
    private var playbackStart: Date?
    private var firstFrameLogged = false
    private var pendingSeekTime: Double?

    init() { setupMPV() }

    deinit {
        stopDisplayLink()
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
        mpv_set_option_string(h, "hwdec", "videotoolbox")
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

    private func setupOpenGL() {
        guard let glCtx = glContext else {
            DebugLogManager.shared?.append("[mpv] FAIL: no OpenGL context")
            return
        }
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
        guard let ctx = renderContext, let glCtx = glContext, let view = renderView else { return }
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let scale = view.window?.backingScaleFactor ?? 2
        let w = Int32(view.bounds.width * scale)
        let h = Int32(view.bounds.height * scale)

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
        case MPV_EVENT_FILE_LOADED:
            runOnMain {
                self.isLoaded = true
                if let pendingSeekTime = self.pendingSeekTime {
                    self.seek(to: pendingSeekTime)
                    self.pendingSeekTime = nil
                }
            }
        case MPV_EVENT_END_FILE:
            guard let data = event.data else { return }
            let endFile = data.assumingMemoryBound(to: mpv_event_end_file.self).pointee
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
                    runOnMain { self.currentTime = val }
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
                }
            default: break
            }
        default: break
        }
    }

    // MARK: - Public API

    func loadFile(_ url: URL) {
        guard let mpv else { return }
        runOnMain { [self] in resetState() }
        playbackStart = Date()
        firstFrameLogged = false
        mpvCommand(mpv, args: ["loadfile", url.path])
    }

    func loadStream(_ url: URL) {
        guard let mpv else { return }
        runOnMain { [self] in resetState() }
        playbackStart = Date()
        firstFrameLogged = false
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
