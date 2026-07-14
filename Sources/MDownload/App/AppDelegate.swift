import Cocoa
import SwiftUI
import ComposableArchitecture

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }
    private var statusIconView: NSImageView!
    private var statusLabel1: NSTextField!
    private var statusLabel2: NSTextField!
    private let statusBarHeight: CGFloat = 22
    private var mainWindowController: FixedWidthWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.send(.appDidFinishLaunching)
        setupStatusBar()
        registerGlobalShortcut()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: Constants.openMainWindowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openVideoDownloaderWindow),
            name: Constants.openDownloaderWindowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openBatchDownloadWindow),
            name: Constants.openBatchWindowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openChannelDownloaderWindow),
            name: Constants.openChannelWindowNotification,
            object: nil
        )

        // Close initial SwiftUI window, then open library
        DispatchQueue.main.async {
            self.hideAllWindows()
            self.openMainWindow()
            self.startClipboardMonitoring()
        }
    }

    private func hideAllWindows() {
        for window in NSApp.windows {
            if window.isVisible {
                window.orderOut(nil)
            }
        }
    }

    private func setupStatusBar() {
        let iconW: CGFloat = 14
        let totalWidth: CGFloat = 88
        statusItem = NSStatusBar.system.statusItem(withLength: totalWidth)
        statusItem?.button?.frame = NSRect(x: 0, y: 0, width: totalWidth, height: statusBarHeight)
        statusItem?.button?.action = #selector(statusBarLeftClicked)
        statusItem?.button?.target = self

        let iconView: NSImageView = {
            let v = NSImageView(frame: NSRect(x: 2, y: 4, width: iconW, height: iconW))
            if let img = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "다운로드") {
                img.size = NSSize(width: iconW, height: iconW)
                v.image = img
                v.contentTintColor = .labelColor
            }
            statusIconView = v
            return v
        }()

        let textX = iconW + 4
        let textW = totalWidth - textX - 2
        let font1 = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let font2 = NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)

        statusLabel1 = NSTextField(labelWithString: "")
        statusLabel1.font = font1
        statusLabel1.textColor = .labelColor
        statusLabel1.alignment = .center
        statusLabel1.frame = NSRect(x: textX, y: 12, width: textW, height: 10)
        statusLabel1.lineBreakMode = .byTruncatingTail

        statusLabel2 = NSTextField(labelWithString: "")
        statusLabel2.font = font2
        statusLabel2.textColor = .secondaryLabelColor
        statusLabel2.alignment = .center
        statusLabel2.frame = NSRect(x: textX, y: 2, width: textW, height: 9)
        statusLabel2.lineBreakMode = .byTruncatingTail

        let container = NSView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: statusBarHeight))
        container.wantsLayer = true
        container.addSubview(iconView)
        container.addSubview(statusLabel1)
        container.addSubview(statusLabel2)
        statusItem?.button?.addSubview(container)

        rebuildMenu()
        updateStatusBarText()

        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updateStatusBarText()
        }

        // Observe appearance changes for dark mode
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc private func appearanceChanged() {
        statusLabel1.textColor = .labelColor
        statusLabel2.textColor = .secondaryLabelColor
        statusIconView.contentTintColor = .labelColor
        updateStatusBarText()
    }

    private func updateStatusBarText() {
        let s = store.statusBar
        if s.hasActiveDownloads, !s.downloadSpeed.isEmpty {
            statusLabel1.alignment = .right
            statusLabel1.stringValue = s.downloadSpeed
            statusLabel2.alignment = .right
            statusLabel2.stringValue = s.downloadETA.isEmpty
                ? "완\(s.completedCount)/\(s.totalCount)"
                : "완\(s.completedCount)/\(s.totalCount) \(s.downloadETA)"
        } else if s.completedCount > 0 {
            statusLabel1.alignment = .center
            statusLabel1.stringValue = "다운로드"
            statusLabel2.alignment = .center
            statusLabel2.stringValue = "완료 \(s.completedCount)/\(s.totalCount)"
        } else {
            statusLabel1.alignment = .center
            statusLabel1.stringValue = "다운로드"
            statusLabel2.alignment = .center
            statusLabel2.stringValue = "대기중"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "라이브러리",
            action: #selector(openMainWindow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "영상 다운로더",
            action: #selector(openVideoDownloaderWindow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "일괄 다운로더",
            action: #selector(openBatchDownloadWindow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "채널 다운로더",
            action: #selector(openChannelDownloaderWindow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "인터넷 속도 측정",
            action: #selector(startSpeedTest),
            keyEquivalent: ""
        ))
        #if DEBUG
        menu.addItem(NSMenuItem(
            title: "상태바 Mock 테스트",
            action: #selector(startStatusBarMockTest),
            keyEquivalent: ""
        ))
        #endif
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "종료",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))
        statusItem?.menu = menu
    }

    @objc private func statusBarLeftClicked() {
        dismissClipboardNotification()
        dismissSpeedTestToast()
        statusItem?.menu = nil
        openMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rebuildMenu()
        }
    }

    @objc func openMainWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "main"
        }) {
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openNewMainWindow()
        }
    }

    @objc private func startSpeedTest() {
        store.send(.statusBar(.startSpeedTest))
        showSpeedTestToast(text: "측정중...")

        Task { [weak self] in
            guard let self = self else { return }
            let testURLs = [
                "https://speed.cloudflare.com/__down?bytes=200000",
                "https://proof.ovh.net/files/1Mb.dat",
                "http://speedtest.tele2.net/1MB.zip",
            ]
            var lastError: Error?

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForResource = 10
            let session = URLSession(configuration: config)

            for urlStr in testURLs {
                guard let url = URL(string: urlStr) else { continue }
                let start = Date()
                do {
                    let (data, response) = try await session.data(from: url)
                    guard let httpResp = response as? HTTPURLResponse,
                          (200...299).contains(httpResp.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    let elapsed = Date().timeIntervalSince(start)
                    guard elapsed > 0 else { continue }
                    let received = data.count
                    let kbps = Double(received) * 8 / elapsed / 1000
                    await MainActor.run {
                        self.store.send(.statusBar(.speedTestUpdate(kbps)))
                        let display = kbps >= 1000
                            ? String(format: "%.1f Mbps", kbps / 1000)
                            : String(format: "%.0f Kbps", kbps)
                        self.showSpeedTestToast(text: display)
                        Task { [weak self] in
                            try? await Task.sleep(for: .seconds(5))
                            await MainActor.run {
                                self?.dismissSpeedTestToast()
                                self?.store.send(.statusBar(.speedTestComplete))
                            }
                        }
                    }
                    return
                } catch {
                    lastError = error
                    continue
                }
            }

            let finalError = lastError
            let statusCode = (finalError as? URLError)?.errorCode ?? -1
            let msg = finalError.map { ($0 as NSError).localizedDescription } ?? "알 수 없는 오류"
            await MainActor.run { [msg, statusCode] in
                self.showSpeedTestToast(text: "실패(\(statusCode)): \(msg)")
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    await MainActor.run {
                        self?.dismissSpeedTestToast()
                        self?.store.send(.statusBar(.speedTestComplete))
                    }
                }
            }
        }
    }

    #if DEBUG
    @objc private func startStatusBarMockTest() {
        store.send(.statusBar(.startStatusBarTest))
    }
    #endif

    private var speedTestToastWindow: NSWindow?

    private func showSpeedTestToast(text: String) {
        dismissSpeedTestToast()

        let hostingCtrl = NSHostingController(rootView: SpeedTestPopoverView(text: text))
        hostingCtrl.view.wantsLayer = true
        hostingCtrl.view.layer?.cornerRadius = 8
        hostingCtrl.view.layer?.masksToBounds = true

        let window = NSWindow(contentViewController: hostingCtrl)
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = true

        if let button = statusItem?.button {
            let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
            let x = buttonFrame.midX - 80
            let y = buttonFrame.minY - 10 - 36
            window.setFrame(NSRect(x: x, y: y, width: 160, height: 36), display: false)
        }
        window.orderFront(nil)
        speedTestToastWindow = window
    }

    private func dismissSpeedTestToast() {
        speedTestToastWindow?.close()
        speedTestToastWindow = nil
    }

    private func openNewMainWindow() {
        let hostingCtrl = NSHostingController(
            rootView: LibraryView(store: store)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        let localizedTitle = Locale.preferredLanguages.first?.hasPrefix("ko") == true
            ? "라이브러리"
            : "Library"
        window.title = localizedTitle
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.showsResizeIndicator = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.contentMinSize = NSSize(width: 840, height: 500)
        window.setContentSize(NSSize(width: 840, height: 640))
        mainWindowController = FixedWidthWindowController(window: window)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openVideoDownloaderWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "downloader"
        }) {
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        dismissClipboardNotification()
        dismissSpeedTestToast()

        let hostingCtrl = NSHostingController(
            rootView: MainView(store: store)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "영상 다운로더"
        window.styleMask = [.titled, .closable, .resizable]
        window.showsResizeIndicator = false
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("downloader")
        window.contentMinSize = NSSize(width: 520, height: 300)
        window.setContentSize(NSSize(width: 520, height: 480))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openBatchDownloadWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "batch"
        }) {
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        dismissClipboardNotification()
        dismissSpeedTestToast()

        let hostingCtrl = NSHostingController(
            rootView: BatchDownloadView(store: store)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "일괄 다운로더"
        window.styleMask = [.titled, .closable, .resizable]
        window.showsResizeIndicator = false
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("batch")
        window.contentMinSize = NSSize(width: 480, height: 340)
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openChannelDownloaderWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "channel"
        }) {
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        dismissClipboardNotification()
        dismissSpeedTestToast()

        let hostingCtrl = NSHostingController(
            rootView: ChannelDownloaderView(store: store)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "채널 다운로더"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.showsResizeIndicator = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("channel")
        window.contentMinSize = NSSize(width: 720, height: 400)
        window.contentMaxSize = NSSize(width: 720, height: 9999)
        window.setContentSize(NSSize(width: 720, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func registerGlobalShortcut() {
        let hotKey = HotKey(
            key: .d,
            modifiers: [.option, .command]
        )
        hotKey.keyDownHandler = { [weak self] in
            self?.openMainWindow()
        }
    }

    private func startClipboardMonitoring() {
        // Ignore clipboard content copied before app launch
        lastClipboardURL = NSPasteboard.general.string(forType: .string)

        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let current = NSPasteboard.general.string(forType: .string)
            guard let url = current, self.isVideoURL(url),
                  url != self.lastClipboardURL
            else { return }
            self.lastClipboardURL = url
            let mainVisible = NSApp.windows.contains { $0.identifier?.rawValue == "main" && $0.isVisible }
            if mainVisible {
                // 라이브러리 창 열려 있으면 다운로더 창을 열고 조회
                DispatchQueue.main.async {
                    self.openVideoDownloaderWindow()
                    self.store.send(.clipboardDetected(url))
                }
            } else {
                // 창이 닫혀 있으면 팝오버 표시 (클릭 시 창 열기 + 조회)
                DispatchQueue.main.async {
                    self.showClipboardNotification(url: url)
                }
            }
        }
    }

    private var clipboardPanel: NSPanel?
    private var pendingClipboardURL: String?
    private var lastClipboardURL: String?

    private func showClipboardNotification(url: String) {
        pendingClipboardURL = url
        dismissClipboardNotification()

        // 시스템 사운드 재생
        NSSound(named: "Pop")?.play()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingCtrl = NSHostingController(
            rootView: ClipboardNotificationView {
                self.dismissClipboardNotification()
                self.pendingClipboardURL = nil
                if let window = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "main"
                }) {
                    window.orderFront(nil)
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self.store.send(.home(.autoFetchInfo(url)))
                } else {
                    self.openNewMainWindow()
                    self.store.send(.home(.autoFetchInfo(url)))
                }
            }
        )
        panel.contentViewController = hostingCtrl
        panel.setContentSize(NSSize(width: 260, height: 62))

        // 상태바 버튼 아래에 패널 위치
        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let panelX = screenRect.midX - 130
            let panelY = screenRect.minY - 72
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        }

        panel.orderFrontRegardless()
        clipboardPanel = panel

        // Auto-dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.dismissClipboardNotification()
        }
    }

    private func dismissClipboardNotification() {
        clipboardPanel?.close()
        clipboardPanel = nil
    }

    private func isVideoURL(_ string: String) -> Bool {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else { return false }
        let hostStr = host.lowercased()

        if hostStr.contains("youtu.be") {
            return true
        }

        if hostStr.contains("youtube.com") {
            let path = url.path.lowercased()
            return path == "/watch" || path.hasPrefix("/watch/")
        }

        let videoHosts = [
            "vimeo.com", "www.vimeo.com",
            "dailymotion.com", "twitch.tv", "www.twitch.tv",
        ]
        return videoHosts.contains { hostStr.contains($0) }
    }
}

struct SpeedTestPopoverView: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "speedometer")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(.body, design: .monospaced).weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: 160, height: 36)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ClipboardNotificationView: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("동영상을 다운로드")
                        .font(.system(size: 12, weight: .semibold))
                    Text("클릭하여 다운로드 창 열기")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 240)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
    }
}

final class HotKey {
    typealias Handler = () -> Void

    enum Key: UInt16 {
        case d = 2
        case a = 0
        case w = 13
        case s = 1
        case f = 3
    }

    struct Modifiers: OptionSet {
        let rawValue: UInt
        static let command = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let shift = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)
    }

    private let key: Key
    private let modifiers: Modifiers
    private var eventHandler: Any?

    var keyDownHandler: Handler?

    init(key: Key, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
        register()
    }

    private func register() {
        var modifierFlags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { modifierFlags.insert(.command) }
        if modifiers.contains(.option) { modifierFlags.insert(.option) }
        if modifiers.contains(.shift) { modifierFlags.insert(.shift) }
        if modifiers.contains(.control) { modifierFlags.insert(.control) }

        eventHandler = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  event.keyCode == self.key.rawValue,
                  event.modifierFlags.contains(modifierFlags)
            else { return event }

            self.keyDownHandler?()
            return nil
        }
    }

    deinit {
        if let handler = eventHandler {
            NSEvent.removeMonitor(handler)
        }
    }
}

private final class FixedWidthWindowController: NSObject, NSWindowDelegate {
    private let fixedWidth: CGFloat
    init(window: NSWindow, width: CGFloat = 840) {
        self.fixedWidth = width
        super.init()
        window.delegate = self
    }
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(width: fixedWidth, height: frameSize.height)
    }
}


