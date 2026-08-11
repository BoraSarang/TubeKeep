import Cocoa
import SwiftUI
import ComposableArchitecture
import UserNotifications
import SwiftData
import AVKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?
    let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }
    private var statusManager: StatusBarManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var channelUpdateService: ChannelUpdateService?
    private var idleSubtitleService: IdleSubtitleService?
    private var videoDownloaderWindow: NSWindow?
    private var libraryWindowController: FixedWidthWindowController?
    private var settingsWindow: NSWindow?
    private var aiWindow: NSWindow?
    private var channelDownloaderWindow: NSWindow?
    private var playerWindow: NSWindow?
    private var playerStore: Store<PlayerReducer.State, PlayerReducer.Action>?

    var isPlayerPlaying: Bool {
        guard let playerStore else { return false }
        return playerStore.withState { $0.isPlaying }
    }
    private var pendingChannelId: String?
    private var pendingChannelData: [String: Any]?
    private var keyMonitor: Any?

    #if DEBUG
    private var debugLogWindow: NSWindow?
    #endif

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminateCleanup),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func terminateCleanup() {
        DebugLogManager.shared?.append("[App] terminateCleanup 시작 PID=\(ProcessInfo.processInfo.processIdentifier)")
        store.send(.downloadQueue(.saveQueue))
        DebugLogManager.shared?.append("[App] ProcessRegistry.killAll: \(ProcessRegistry.killAll())개")
        DebugLogManager.shared?.append("[App] DownloadManager.cancelAll: \(DownloadManager.shared.cancelAll())개")
        DebugLogManager.shared?.append("[App] 1차 killAllChildProcesses")
        killAllChildProcesses()
        usleep(500_000)
        DebugLogManager.shared?.append("[App] 2차 killAllChildProcesses")
        killAllChildProcesses()
        DebugLogManager.shared?.append("[App] terminateCleanup 완료")
    }

func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        ProcessInfo.processInfo.disableSuddenTermination()

        #if DEBUG
        let logManager = DebugLogManager()
        DebugLogManager.shared = logManager
        logManager.append("[App] TubeKeep 시작")
        #endif

        // 이전 인스턴스(강제 종료)가 남긴 고아 yt-dlp/yt_dlp를 먼저 정리한 뒤
        // 큐 로드/자동 재개가 수행되도록 순서를 앞당긴다.
        // (기존: .appDidFinishLaunching 실행으로 큐 자동 재개가 yt-dlp를 띄운 뒤
        //  cleanupStaleChildProcesses가 pkill로 방금 시작한 yt-dlp까지 kill → 다운로드 정지 버그 수정)
        cleanupStaleChildProcesses()

        store.send(.appDidFinishLaunching)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { DebugLogManager.shared?.append("[App] 알림 권한 요청 실패: \(error)") }
        }

        setupManagers()

        LibraryCacheService.shared.autoPurgeTrash(olderThan: 30)
        LibraryCacheService.shared.migrateChannelIDs()

        Task { await BundledLibraryManager.shared.warmUp() }

        checkForUpdate()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloaderNotification(_:)),
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPlayerWindow(_:)),
            name: Constants.openPlayerWindowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openWhisperSettings),
            name: Constants.openWhisperSettingsNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMainMenu),
            name: GlobalShortcutService.didChangeNotification,
            object: nil
        )

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 영상 플레이어 창이 활성일 때 스페이스바(49) → 재생/일시정지
            if event.keyCode == 49 {
                #if DEBUG
                let cmd = event.modifierFlags.contains(.command)
                Task { @MainActor in
                    DebugLogManager.shared?.append("[Key] Space — cmd=\(cmd) playerWindow=\(String(describing: self.playerWindow != nil)) isKey=\(self.playerWindow?.isKeyWindow ?? false) keyWin=\(String(describing: NSApp.keyWindow?.identifier?.rawValue))")
                }
                #endif
                if !event.modifierFlags.contains(.command),
                   let player = self.playerWindow, player.isKeyWindow {
                    NotificationCenter.default.post(name: Constants.playerTogglePlayPauseNotification, object: nil)
                    return nil
                }
            }
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 43: // , (settings)
                    self.openSettingsWindow()
                    return nil
                case 12: // q (quit)
                    NSApp.terminate(nil)
                    return nil
                case 7: // x (cut)
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                    return nil
                case 8: // c (copy)
                    #if DEBUG
                    if event.modifierFlags.contains(.shift) {
                        DebugLogManager.shared?.copySelection()
                        return nil
                    }
                    #endif
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                    return nil
                case 9: // v (paste)
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                    return nil
                case 0: // a (selectAll)
                    #if DEBUG
                    if event.modifierFlags.contains(.shift) {
                        DebugLogManager.shared?.copyAll()
                        return nil
                    }
                    #endif
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    return nil
                case 2: // d (debug panel toggle)
                    #if DEBUG
                    self.toggleDebugLogWindow()
                    return nil
                    #else
                    return event
                    #endif
                case 40: // k (clear logs)
                    #if DEBUG
                    DebugLogManager.shared?.clear()
                    return nil
                    #else
                    return event
                    #endif
                case 1: // s (auto scroll toggle)
                    #if DEBUG
                    if event.modifierFlags.contains(.shift) {
                        self.debugToggleAutoScroll()
                        return nil
                    }
                    #endif
                    return event
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

            if !Settings.loadSettings().showMainWindowOnLaunch {
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
        #if DEBUG
        statusBar.onToggleDebugPanel = { [weak self] in self?.toggleDebugLogWindow() }
        #endif
        statusManager = statusBar

        IdleNotificationPresenter.shared.configure(statusItem: statusBar.statusItem)

        let clipboard = ClipboardMonitor()
        clipboard.onVideoDetected = { [weak self] url in
            self?.openVideoDownloaderWindow()
            self?.store.send(.home(.autoFetchInfo(url)))
        }
        clipboardMonitor = clipboard

        let channelUpdate = ChannelUpdateService(store: store)
        channelUpdate.start()
        channelUpdateService = channelUpdate

        let idleSubtitle = IdleSubtitleService(store: store)
        idleSubtitle.start()
        idleSubtitleService = idleSubtitle

        GlobalShortcutService.shared.start()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "TubeKeep에 대하여", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "TubeKeep 설정…", action: #selector(openSettingsWindow), keyEquivalent: "")
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

        addShortcutMenu(to: mainMenu)

        #if DEBUG
        let debugMenuItem = NSMenuItem()
        mainMenu.addItem(debugMenuItem)
        let debugMenu = NSMenu(title: "Debug")

        let showHideItem = debugMenu.addItem(withTitle: "Show/Hide Debug Panel", action: #selector(toggleDebugLogWindow), keyEquivalent: "d")
        showHideItem.target = self

        debugMenu.addItem(.separator())

        let copySelItem = debugMenu.addItem(withTitle: "Copy Selection", action: #selector(debugCopySelection), keyEquivalent: "c")
        copySelItem.keyEquivalentModifierMask = [.command, .shift]
        copySelItem.target = self

        let copyAllItem = debugMenu.addItem(withTitle: "Copy All for Agent", action: #selector(debugCopyAll), keyEquivalent: "a")
        copyAllItem.keyEquivalentModifierMask = [.command, .shift]
        copyAllItem.target = self

        let clearItem = debugMenu.addItem(withTitle: "Clear Logs", action: #selector(debugClear), keyEquivalent: "k")
        clearItem.keyEquivalentModifierMask = .command
        clearItem.target = self

        debugMenu.addItem(.separator())

        let scrollItem = debugMenu.addItem(withTitle: "Auto Scroll (📌)", action: #selector(debugToggleAutoScroll), keyEquivalent: "s")
        scrollItem.keyEquivalentModifierMask = [.command, .shift]
        scrollItem.target = self

        debugMenuItem.submenu = debugMenu
        #endif

        NSApp.mainMenu = mainMenu
    }

    private func addShortcutMenu(to mainMenu: NSMenu) {
        let menuItem = NSMenuItem()
        mainMenu.addItem(menuItem)
        let menu = NSMenu(title: "다운로더")

        let bindings = GlobalShortcutService.shared.loadBindings()

        addShortcutItem(to: menu, title: "영상 다운로더", action: #selector(openVideoDownloaderWindow), actionKey: .openDownloader, bindings: bindings)
        addShortcutItem(to: menu, title: "일괄 다운로더", action: #selector(openBatchDownloadWindow), actionKey: .openBatchDownloader, bindings: bindings)
        addShortcutItem(to: menu, title: "채널 다운로더", action: #selector(openChannelDownloaderWindow), actionKey: .openChannelDownloader, bindings: bindings)

        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "설정…", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self

        menuItem.submenu = menu
    }

    private func addShortcutItem(to menu: NSMenu, title: String, action: Selector, actionKey: GlobalShortcutAction, bindings: [GlobalShortcutAction: HotKeyBinding]) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: actionKey.icon, accessibilityDescription: nil)
        item.target = self
        if let binding = bindings[actionKey], binding.isEnabled, binding.keyCode > 0 {
            let eq = GlobalShortcutService.shared.menuKeyEquivalent(for: binding)
            if eq.key.count == 1, eq.modifiers.contains(.command) {
                item.keyEquivalent = eq.key
                item.keyEquivalentModifierMask = eq.modifiers
            } else {
                item.title = "\(title)\t\(binding.display)"
            }
        }
        menu.addItem(item)
    }

    @objc private func refreshMainMenu() {
        setupMainMenu()
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
        DebugLogManager.shared?.append("[App] TubeKeep 창 생성")
        #endif
        let rootView = MainView(store: store)
            .modelContainer(PersistenceController.shared.container)

        let localizedTitle = Locale.preferredLanguages.first?.hasPrefix("ko") == true
            ? "튜브킵"
            : "TubeKeep"
        let window = WindowFactory.makeWindow(
            identifier: "lib",
            title: localizedTitle,
            rootView: rootView,
            contentSize: NSSize(width: 840, height: 640),
            minSize: NSSize(width: 840, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable]
        )
        let controller = FixedWidthWindowController(window: window)
        libraryWindowController = controller
        WindowFactory.present(window)
    }

    // MARK: - Video Downloader Window

    @objc func openVideoDownloaderWindow() {
        if let window = videoDownloaderWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        clipboardMonitor?.dismiss()

        #if DEBUG
        DebugLogManager.shared?.append("[Downloader] 창 생성")
        #endif
        let rootView = VideoDownloadView(store: store)

        let window = WindowFactory.makeWindow(
            identifier: "downloader",
            title: "영상 다운로더",
            rootView: rootView,
            contentSize: NSSize(width: 520, height: 480),
            minSize: NSSize(width: 520, height: 300),
            styleMask: [.titled, .closable, .resizable],
            zoomEnabled: false
        )
        WindowFactory.present(window)
        videoDownloaderWindow = window
    }

    @objc private func handleDownloaderNotification(_ notification: Notification) {
        openVideoDownloaderWindow()
        if let url = notification.userInfo?["url"] as? String {
            store.send(.home(.setURL(url)))
            store.send(.home(.autoFetchInfo(url)))
        }
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

        #if DEBUG
        DebugLogManager.shared?.append("[Batch] 창 생성")
        #endif
        let rootView = BatchDownloadView(store: store)

        let window = WindowFactory.makeWindow(
            identifier: "batch",
            title: "일괄 다운로더",
            rootView: rootView,
            contentSize: NSSize(width: 480, height: 420),
            minSize: NSSize(width: 480, height: 340),
            styleMask: [.titled, .closable, .resizable],
            zoomEnabled: false
        )
        WindowFactory.present(window)
    }

    // MARK: - Channel Downloader Window

    @objc func openChannelDownloaderWindow() {
        if let window = channelDownloaderWindow {
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

        #if DEBUG
        DebugLogManager.shared?.append("[Channel] 창 생성")
        #endif
        let rootView = ChannelDownloaderView(store: store, initialChannelId: pendingChannelId, pendingChannelData: pendingChannelData)

        pendingChannelId = nil
        pendingChannelData = nil
        let window = WindowFactory.makeWindow(
            identifier: "channel",
            title: "채널 다운로더",
            rootView: rootView,
            contentSize: NSSize(width: 720, height: 520),
            minSize: NSSize(width: 720, height: 400),
            maxSize: NSSize(width: 720, height: 9999),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            zoomEnabled: false
        )
        WindowFactory.present(window)
        channelDownloaderWindow = window
    }

    @objc private func openChannelDownloaderFromNotification(_ notification: Notification) {
        let info = (notification.userInfo as? [String: Any]) ?? [:]
        pendingChannelData = info
        pendingChannelId = info["channelId"] as? String
        openChannelDownloaderWindow()
    }

    // MARK: - About Window

    @objc func openAboutWindow() {
        let window = WindowFactory.makeWindow(
            identifier: "about",
            title: "정보",
            rootView: AboutView(),
            contentSize: NSSize(width: 440, height: 200),
            minSize: NSSize(width: 440, height: 200)
        )
        WindowFactory.present(window)
    }

    // MARK: - Settings Window

    @objc private func openSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = WindowFactory.makeWindow(
            identifier: "settings",
            title: "설정",
            rootView: SettingsView(store: store.scope(state: \.settings, action: \.settings)),
            contentSize: NSSize(width: 640, height: 420)
        )
        window.contentMinSize = window.frame.size
        window.contentMaxSize = window.frame.size
        WindowFactory.present(window)
        settingsWindow = window
    }

    @objc private func openWhisperSettings() {
        store.send(.settings(.setSelectedTab(.ai)))
        openSettingsWindow()
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

        let window = WindowFactory.makeWindow(
            identifier: "qna",
            title: "AI 기능",
            rootView: AIWindowView(store: store),
            contentSize: NSSize(width: 560, height: windowHeight)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        aiWindow = window
    }

    // MARK: - Player Window

    @objc private func openPlayerWindow(_ notification: Notification) {
        guard let playerItem = notification.object as? PlayerItem else { return }

        if let existingStore = playerStore, let window = playerWindow, window.isVisible || window.isMiniaturized {
            existingStore.send(.loadVideo(playerItem))
            if let queue = notification.userInfo?["queue"] as? [PlayerItem] {
                let startIndex = notification.userInfo?["startIndex"] as? Int ?? 0
                existingStore.send(.setQueue(queue, startIndex: startIndex))
            }
            window.title = playerItem.title
            if notification.userInfo?["suppressBringToFront"] as? Bool != true {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }

        let newStore = Store(initialState: PlayerReducer.State(playerItem: playerItem)) {
            PlayerReducer()
        }
        playerStore = newStore
        if let queue = notification.userInfo?["queue"] as? [PlayerItem] {
            let startIndex = notification.userInfo?["startIndex"] as? Int ?? 0
            newStore.send(.setQueue(queue, startIndex: startIndex))
        }
        if playerItem.fileURL == nil, playerItem.videoId != nil {
            newStore.send(.loadVideo(playerItem))
        }
        let playerView = PlayerView(store: newStore)
        let hostingCtrl = NSHostingController(rootView: playerView)
        let window = PlayerWindow(contentViewController: hostingCtrl)
        window.title = playerItem.title
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .ignoresCycle, .fullScreenPrimary]
        window.identifier = NSUserInterfaceItemIdentifier("player")
        window.setContentSize(NSSize(width: 854, height: 480))
        window.contentMinSize = NSSize(width: 854, height: 480)
        window.isRestorable = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        playerWindow = window
    }

    // MARK: - Debug Log Window

    #if DEBUG
    @objc func toggleDebugLogWindow() {
        if let window = debugLogWindow, window.isVisible {
            window.orderOut(nil)
            return
        }
        if let window = debugLogWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = WindowFactory.makeWindow(
            identifier: "debugLog",
            title: "🐛 Debug Logs",
            rootView: DebugLogWindowView(),
            contentSize: NSSize(width: 600, height: 320),
            minSize: NSSize(width: 400, height: 200),
            maxSize: NSSize(width: 2000, height: 1200),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            level: .floating + 100,
            movableByBackground: true
        )
        WindowFactory.present(window)
        debugLogWindow = window
    }

    @objc func debugCopySelection() {
        DebugLogManager.shared?.copySelection()
    }

    @objc func debugCopyAll() {
        DebugLogManager.shared?.copyAll()
    }

    @objc func debugClear() {
        DebugLogManager.shared?.clear()
    }

    @objc func debugToggleAutoScroll() {
        guard let manager = DebugLogManager.shared else { return }
        manager.autoScroll.toggle()
    }
    #endif

    // MARK: - Update Check

    private func checkForUpdate() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let update = await UpdateChecker.checkForUpdate() else { return }

            let alert = NSAlert()
            alert.messageText = "업데이트 가능"
            alert.informativeText = "TubeKeep \(update.latestVersion) 사용 가능합니다.\n현재 버전: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
            if let notes = update.releaseNotes {
                alert.informativeText += "\n\n변경 사항:\n\(notes)"
            }
            alert.addButton(withTitle: "다운로드")
            alert.addButton(withTitle: "나중에")
            alert.addButton(withTitle: "이 버전 건너뛰기")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                if let url = URL(string: update.downloadURL) {
                    NSWorkspace.shared.open(url)
                }
            case .alertThirdButtonReturn:
                UpdateChecker.skipVersion(update.latestVersion)
            default:
                break
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue == "player" else { return }
        playerWindow = nil
    }

    // MARK: - Process Cleanup

    /// 강제 종료(SIGKILL)로 `terminateCleanup`이 실행되지 못해 남은 이전 인스턴스의
    /// yt-dlp/yt_dlp 하위 프로세스를 앱 시작 시 정리한다.
    private func cleanupStaleChildProcesses() {
        let pid = ProcessInfo.processInfo.processIdentifier
        // 고아가 된 yt-dlp/yt_dlp(강제 종료로 부모와 연결이 끊긴 것)를 먼저 정리.
        // 부모 관점(-P)으로는 강제 종료 후 남은 고아(PPID=1)는 잡히지 않으므로 -f 매칭을 사용한다.
        let cmd = "pkill -9 -f 'yt_dlp' 2>/dev/null; pkill -9 -f 'yt-dlp' 2>/dev/null; pkill -9 -P \(pid) 2>/dev/null"
        let bash = Process()
        bash.executableURL = URL(fileURLWithPath: "/bin/bash")
        bash.arguments = ["-c", cmd]
        do {
            try bash.run()
            bash.waitUntilExit()
            DebugLogManager.shared?.append("[App] 시작 시 잔여 프로세스 정리 완료")
        } catch {
            DebugLogManager.shared?.append("[App] 시작 시 잔여 프로세스 정리 실패: \(error)")
        }
    }

    private func killAllChildProcesses() {
        let pid = ProcessInfo.processInfo.processIdentifier
        // 1. pkill -P 로 전체 자식 정리
        let cmd = "pkill -9 -P \(pid) 2>/dev/null; pkill -9 -f yt-dlp 2>/dev/null; pkill -9 -f yt_dlp 2>/dev/null"
        let bash = Process()
        bash.executableURL = URL(fileURLWithPath: "/bin/bash")
        bash.arguments = ["-c", cmd]
        do {
            try bash.run()
            bash.waitUntilExit()
        } catch {
            DebugLogManager.shared?.append("[App] killAllChildProcesses: bash fail \(error)")
        }
        // 2. 남은 자식 확인
        let remain = childPIDs(pid)
        if remain.isEmpty {
            DebugLogManager.shared?.append("[App] killAllChildProcesses: 자식 없음")
        } else {
            DebugLogManager.shared?.append("[App] killAllChildProcesses: \(remain.count)개 남음 PIDs=\(remain)")
            for leftover in remain {
                kill(leftover, SIGKILL)
                DebugLogManager.shared?.append("[App] 직접 SIGKILL: PID=\(leftover)")
            }
            usleep(200_000)
            let remain2 = childPIDs(pid)
            DebugLogManager.shared?.append("[App] 재시도 후: \(remain2.count)개 남음")
        }
    }

    private func childPIDs(_ pid: Int32) -> [Int32] {
        let pgrep = Process()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-P", "\(pid)"]
        let out = Pipe()
        pgrep.standardOutput = out
        try? pgrep.run()
        pgrep.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - URL Scheme

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let components = URLComponents(string: urlString) else { return }

        let host = (components.host ?? "").lowercased()

        if host == "add" || host == "open" {
            let query = components.queryItems ?? []
            if let urlValue = query.first(where: { $0.name == "url" })?.value,
               let target = URL(string: urlValue) {
                DispatchQueue.main.async {
                    self.openVideoDownloaderWindow()
                    self.store.send(.home(.setURL(target.absoluteString)))
                    self.store.send(.home(.autoFetchInfo(target.absoluteString)))
                }
            } else if let id = query.first(where: { $0.name == "id" })?.value {
                openLibraryItem(videoId: id)
            }
            return
        }

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

    private func openLibraryItem(videoId: String) {
        DispatchQueue.main.async {
            guard let item = self.store.state.library.items.first(where: { $0.id == videoId }) else {
                NSSound.beep()
                return
            }
            let playerItem = PlayerItem(
                fileURL: URL(fileURLWithPath: item.filePath),
                title: item.title,
                videoId: item.id,
                duration: Double(item.duration ?? 0)
            )
            NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem)
        }
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
