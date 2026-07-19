import Cocoa
import SwiftUI
import ComposableArchitecture
import UserNotifications
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }
    private var statusManager: StatusBarManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var channelUpdateService: ChannelUpdateService?
    private var videoDownloaderWindow: NSWindow?
    private var libraryWindowController: FixedWidthWindowController?
    private var settingsWindow: NSWindow?
    private var aiWindow: NSWindow?
    private var speedTestToastWindow: NSWindow?
    private var pendingChannelId: String?
    private var pendingChannelData: [String: Any]?
    private var keyMonitor: Any?

    #if DEBUG
    private var libraryLogManager: DebugLogManager?
    private var downloaderLogManager: DebugLogManager?
    private var batchLogManager: DebugLogManager?
    private var channelLogManager: DebugLogManager?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.send(.appDidFinishLaunching)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("알림 권한 요청 실패: \(error)") }
        }

        #if DEBUG
        let logManager = DebugLogManager()
        DebugLogManager.shared = logManager
        logManager.append("[App] TubeKeep 시작")
        #endif

        setupManagers()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openChannelDownloaderFromNotification(_:)),
            name: Constants.openChannelWithIdNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsWindow),
            name: Constants.openSettingsWindowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openAIWindow),
            name: Constants.openAIWindowNotification,
            object: nil
        )

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 49: // , (settings)
                    self.openSettingsWindow()
                    return nil
                case 12: // q (quit)
                    NSApp.terminate(nil)
                    return nil
                case 7: // x (cut)
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                    return nil
                case 8: // c (copy)
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                    return nil
                case 9: // v (paste)
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                    return nil
                case 0: // a (selectAll)
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    return nil
                default:
                    return event
                }
            }
            return event
        }

        setupMainMenu()

        DispatchQueue.main.async {
            self.migrateLibraryData()
            BookmarkManager.ensureAccess()
            SwiftDataMigration.migrateIfNeeded(context: PersistenceController.shared.context)

            if let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
               let data = json.data(using: .utf8),
               let settings = try? JSONDecoder().decode(Settings.self, from: data),
               !settings.showMainWindowOnLaunch {
            } else {
                self.openMainWindow()
            }
            self.clipboardMonitor?.start(statusItem: self.statusManager?.statusItem)
        }
    }

    private func setupManagers() {
        let statusBar = StatusBarManager(store: store)
        statusBar.onOpenMainWindow = { [weak self] in self?.openMainWindow() }
        statusBar.onOpenVideoDownloader = { [weak self] in self?.openVideoDownloaderWindow() }
        statusBar.onOpenBatchDownload = { [weak self] in self?.openBatchDownloadWindow() }
        statusBar.onOpenChannelDownloader = { [weak self] in self?.openChannelDownloaderWindow() }
        statusBar.onOpenSettings = { [weak self] in self?.openSettingsWindow() }
        statusBar.onOpenAbout = { [weak self] in self?.openAboutWindow() }
        statusBar.onStartSpeedTest = { [weak self] in self?.startSpeedTest() }
        #if DEBUG
        statusBar.onStartMockTest = { [weak self] in
            self?.store.send(.statusBar(.startStatusBarTest))
        }
        statusBar.onTriggerChannelUpdate = { [weak self] in
            guard let self else { return }
            Task { await self.channelUpdateService?.checkForUpdates() }
        }
        #endif
        statusManager = statusBar

        let clipboard = ClipboardMonitor()
        clipboard.onVideoDetected = { [weak self] url in
            self?.openVideoDownloaderWindow()
            self?.store.send(.home(.autoFetchInfo(url)))
        }
        clipboardMonitor = clipboard

        let channelUpdate = ChannelUpdateService(store: store)
        #if DEBUG
        let logManager = DebugLogManager()
        channelUpdate.setLogManager(logManager)
        channelLogManager = logManager
        #endif
        channelUpdate.start()
        channelUpdateService = channelUpdate
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "TubeKeep에 대하여", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "TubeKeep 설정…", action: #selector(openSettingsWindow), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "TubeKeep 숨기기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "다른 항목 숨기기", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "모두 표시", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "TubeKeep 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "다시 실행", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "모두 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func migrateLibraryData() {
        let saveKey = "downloadLibrary"
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupSuiteName)
        guard sharedDefaults?.data(forKey: saveKey) == nil,
              let data = UserDefaults.standard.data(forKey: saveKey)
        else { return }
        sharedDefaults?.set(data, forKey: saveKey)
    }

    // MARK: - Library Window

    @objc func openMainWindow() {
        if let controller = libraryWindowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        #if DEBUG
        if DebugLogManager.shared == nil {
            let logManager = DebugLogManager()
            DebugLogManager.shared = logManager
        }
        let logManager = DebugLogManager.shared!
        libraryLogManager = logManager
        logManager.append("[App] TubeKeep 창 생성")
        let rootView = MainView(store: store)
            .debugLogOverlay(manager: logManager)
            .modelContainer(PersistenceController.shared.container)
        #else
        let rootView = MainView(store: store)
            .modelContainer(PersistenceController.shared.container)
        #endif

        let hostingCtrl = NSHostingController(rootView: rootView)
        let localizedTitle = Locale.preferredLanguages.first?.hasPrefix("ko") == true
            ? "튜브킵"
            : "TubeKeep"
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = localizedTitle
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.showsResizeIndicator = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("lib")
        window.contentMinSize = NSSize(width: 840, height: 500)
        window.setContentSize(NSSize(width: 840, height: 640))
        let controller = FixedWidthWindowController(window: window)
        libraryWindowController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Speed Test

    @objc private func startSpeedTest() {
        store.send(.statusBar(.startSpeedTest))
        showSpeedTestToast(text: "측정 중...")

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

                    if let button = statusManager?.statusItem.button {
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

    // MARK: - Video Downloader Window

    @objc func openVideoDownloaderWindow() {
        if let window = videoDownloaderWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        clipboardMonitor?.dismiss()
        dismissSpeedTestToast()

        #if DEBUG
        let logManager = DebugLogManager()
        downloaderLogManager = logManager
        logManager.append("영상 다운로더 창 생성")
        let rootView = VideoDownloadView(store: store)
            .debugLogOverlay(manager: logManager)
        #else
        let rootView = VideoDownloadView(store: store)
        #endif

        let hostingCtrl = NSHostingController(rootView: rootView)
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
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        videoDownloaderWindow = window
    }

    // MARK: - Batch Download Window

    @objc private func openBatchDownloadWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "batch"
        }) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        clipboardMonitor?.dismiss()
        dismissSpeedTestToast()

        #if DEBUG
        let logManager = DebugLogManager()
        batchLogManager = logManager
        logManager.append("일괄 다운로더 창 생성")
        let rootView = BatchDownloadView(store: store)
            .debugLogOverlay(manager: logManager)
        #else
        let rootView = BatchDownloadView(store: store)
        #endif

        let hostingCtrl = NSHostingController(rootView: rootView)
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
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Channel Downloader Window

    @objc func openChannelDownloaderWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "channel"
        }) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            if let data = pendingChannelData {
                NotificationCenter.default.post(
                    name: Constants.selectChannelNotification,
                    object: nil,
                    userInfo: data
                )
            }
            pendingChannelId = nil
            pendingChannelData = nil
            return
        }

        clipboardMonitor?.dismiss()
        dismissSpeedTestToast()

        #if DEBUG
        let logManager = DebugLogManager()
        channelLogManager = logManager
        logManager.append("채널 다운로더 창 생성")
        let rootView = ChannelDownloaderView(store: store, initialChannelId: pendingChannelId, pendingChannelData: pendingChannelData)
            .debugLogOverlay(manager: logManager)
        #else
        let rootView = ChannelDownloaderView(store: store, initialChannelId: pendingChannelId, pendingChannelData: pendingChannelData)
        #endif

        pendingChannelId = nil
        pendingChannelData = nil
        let hostingCtrl = NSHostingController(rootView: rootView)
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
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openChannelDownloaderFromNotification(_ notification: Notification) {
        let info = (notification.userInfo as? [String: Any]) ?? [:]
        pendingChannelData = info
        pendingChannelId = info["channelId"] as? String
        openChannelDownloaderWindow()
    }

    // MARK: - About Window

    @objc func openAboutWindow() {
        let hostingCtrl = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "정보"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("about")
        window.contentMinSize = NSSize(width: 440, height: 200)
        window.setContentSize(NSSize(width: 440, height: 200))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings Window

    @objc private func openSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingCtrl = NSHostingController(
            rootView: SettingsView(store: store.scope(state: \.settings, action: \.settings))
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "설정"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        window.setContentSize(NSSize(width: 560, height: 420))
        window.contentMinSize = window.frame.size
        window.contentMaxSize = window.frame.size
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func openAIWindow() {
        if let window = aiWindow {
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async {
                window.makeFirstResponder(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let windowHeight = min(560, screenHeight - 40)

        let hostingCtrl = NSHostingController(
            rootView: AIWindowView(store: store)
        )
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = "AI 기능"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .ignoresCycle]
        window.identifier = NSUserInterfaceItemIdentifier("qna")
        window.setContentSize(NSSize(width: 560, height: windowHeight))
        window.center()
        window.center()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        aiWindow = window
    }

    // MARK: - URL Scheme

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        let videoURL = urlString
            .replacingOccurrences(of: "tubekeep://", with: "https://")
            .replacingOccurrences(of: "tubekeep:", with: "https://")
        guard videoURL != urlString else { return }
        DispatchQueue.main.async {
            self.openVideoDownloaderWindow()
            self.store.send(.home(.setURL(videoURL)))
            self.store.send(.home(.autoFetchInfo(videoURL)))
        }
    }
}

// MARK: - Helper Views

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
