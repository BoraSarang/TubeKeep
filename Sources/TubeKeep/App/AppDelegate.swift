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
    private var libraryWindow: NSWindow?
    private var aiWindow: NSWindow?
    private var channelDownloaderWindow: NSWindow?
    private var playerWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var playerStore: Store<PlayerReducer.State, PlayerReducer.Action>?

    var isPlayerPlaying: Bool {
        guard let playerStore else { return false }
        return playerStore.withState { $0.isPlaying }
    }
    private var pendingChannelId: String?
    private var pendingChannelData: [String: Any]?
    private var keyMonitor: Any?
    private var keyCommandHandler: KeyCommandHandler?

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

        #if DEBUG
        let debugPanelHandler: (() -> Void)? = { [weak self] in self?.toggleDebugLogWindow() }
        let debugAutoScrollHandler: (() -> Void)? = { [weak self] in self?.debugToggleAutoScroll() }
        #else
        let debugPanelHandler: (() -> Void)? = nil
        let debugAutoScrollHandler: (() -> Void)? = nil
        #endif
        let keyHandler = KeyCommandHandler(
            isPlayerKeyWindow: { [weak self] in
                guard let player = self?.playerWindow else { return false }
                return player.isKeyWindow || (player.isVisible && NSApp.isActive)
            },
            onTogglePlayerPlayPause: {
                #if DEBUG
                DebugLogManager.shared?.append("[Key] post togglePlayPause")
                #endif
                NotificationCenter.default.post(name: Constants.playerTogglePlayPauseNotification, object: nil)
            },
            onVolumeChange: { delta in
                NotificationCenter.default.post(name: Constants.playerVolumeChangeNotification, object: nil, userInfo: ["delta": delta])
            },
            onOpenSettings: { [weak self] in self?.openSettingsWindow() },
            onToggleDebugPanel: debugPanelHandler,
            onToggleDebugAutoScroll: debugAutoScrollHandler
        )
        keyCommandHandler = keyHandler
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak keyHandler] event in
            keyHandler?.handle(event) ?? event
        }

        setupMainMenu()

        DispatchQueue.main.async {
            self.setupMainMenu()
            self.migrateLibraryData()
            if BookmarkManager.ensureAccess() {
                DebugLogManager.shared?.append("[STORAGE] 시작 시 저장 폴더 접근 활성화")
            } else {
                DebugLogManager.shared?.append("[ERROR] E-MAC-STOR-1001 시작 시 저장 폴더 접근 실패")
                BookmarkManager.promptReselectStorageDirectoryIfNeeded()
            }
            SwiftDataMigration.migrateIfNeeded(context: PersistenceController.shared.context)

            if Settings.loadSettings().showLibraryOnLaunch {
                self.openLibraryWindow()
            }
            self.clipboardMonitor?.start(statusItem: self.statusManager?.statusItem)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // SwiftUI가 시작 직후 기본 메뉴로 NSApp.mainMenu를 교체할 수 있어 한 번 더 복구한다.
            self.setupMainMenu()
        }
    }

    private func setupManagers() {
        let statusBar = StatusBarManager(store: store)
        statusBar.onOpenLibraryWindow = { [weak self] in self?.openLibraryWindow() }
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

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "파일")
        let closeItem = fileMenu.addItem(withTitle: "창 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        closeItem.target = nil
        fileMenuItem.submenu = fileMenu

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

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "보기")
        addWindowMenuItem(to: viewMenu, title: "보관함", action: #selector(openLibraryWindow), keyEquivalent: "1", modifiers: [.command])
        addWindowMenuItem(to: viewMenu, title: "영상 다운로더", action: #selector(openVideoDownloaderWindow), keyEquivalent: "2", modifiers: [.command])
        addWindowMenuItem(to: viewMenu, title: "일괄 다운로더", action: #selector(openBatchDownloadWindow), keyEquivalent: "3", modifiers: [.command])
        addWindowMenuItem(to: viewMenu, title: "채널 다운로더", action: #selector(openChannelDownloaderWindow), keyEquivalent: "4", modifiers: [.command])
        viewMenu.addItem(.separator())
        addWindowMenuItem(to: viewMenu, title: "AI 질문", action: #selector(openAIWindow), keyEquivalent: "a", modifiers: [.command, .shift])
        viewMenu.addItem(.separator())
        addWindowMenuItem(to: viewMenu, title: "설정…", action: #selector(openSettingsWindow), keyEquivalent: ",", modifiers: [.command])
        viewMenuItem.submenu = viewMenu

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "창")
        windowMenu.addItem(withTitle: "창 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(.separator())
        let frontItem = windowMenu.addItem(withTitle: "모든 창 앞으로", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        frontItem.target = NSApp
        windowMenuItem.submenu = windowMenu

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "도움말")
        let helpItem = helpMenu.addItem(withTitle: "TubeKeep 도움말", action: #selector(openHelpURL), keyEquivalent: "")
        helpItem.target = self
        helpMenuItem.submenu = helpMenu

        #if DEBUG
        let debugMenuItem = NSMenuItem()
        mainMenu.addItem(debugMenuItem)
        let debugMenu = NSMenu(title: "Debug")

        let showHideItem = debugMenu.addItem(withTitle: "Show/Hide Debug Panel (⌘D)", action: #selector(toggleDebugLogWindow), keyEquivalent: "")
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

    func applicationDidBecomeActive(_ notification: Notification) {
        setupMainMenu()
    }

    /// Dock 아이콘 클릭 시 보관함 창이 없으면 다시 연다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openLibraryWindow()
        }
        return true
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

    private func addWindowMenuItem(to menu: NSMenu, title: String, action: Selector, keyEquivalent: String, modifiers: NSEvent.ModifierFlags) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
    }

    @objc private func openHelpURL() {
        NSWorkspace.shared.open(URL(string: "https://github.com/borasarang/TubeKeep")!)
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

    @objc func openLibraryWindow() {
        if let window = libraryWindow {
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
            contentSize: NSSize(width: 1000, height: 700),
            minSize: NSSize(width: 840, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            titlebarIcon: WindowFactory.icon("square.grid.2x2"),
            fullSizeTitlebar: true,
            autosaveName: "TubeKeepMain"
        )
        WindowFactory.present(window)
        libraryWindow = window
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
            contentSize: NSSize(width: 640, height: 560),
            minSize: NSSize(width: 560, height: 420),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            titlebarIcon: WindowFactory.icon("arrow.down.circle"),
            autosaveName: "TubeKeepDownloader"
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
            contentSize: NSSize(width: 640, height: 560),
            minSize: NSSize(width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            titlebarIcon: WindowFactory.icon("shippingbox"),
            autosaveName: "TubeKeepBatch"
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
            contentSize: NSSize(width: 800, height: 600),
            minSize: NSSize(width: 700, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            titlebarIcon: WindowFactory.icon("tv"),
            autosaveName: "TubeKeepChannel"
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
            minSize: NSSize(width: 440, height: 200),
            titlebarIcon: WindowFactory.icon("info.circle")
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
            contentSize: NSSize(width: 760, height: 500),
            autosaveName: "TubeKeepSettings"
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
        let windowHeight = min(540, screenHeight - 40)

        let window = WindowFactory.makeWindow(
            identifier: "qna",
            title: "AI 기능",
            rootView: AIWindowView(store: store),
            contentSize: NSSize(width: 520, height: windowHeight),
            titlebarIcon: WindowFactory.icon("sparkle"),
            autosaveName: "TubeKeepAI"
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

        // 플레이어 창·mpv는 앱 생명주기 동안 1개만 유지하고 재사용한다.
        // "닫기"는 orderOut 숨김(performClose 오버라이드)이므로 숨겨진 창도
        // 이 경로로 복원된다. (T-1208)
        if let existingStore = playerStore, let window = playerWindow {
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
        let playerView = PlayerView(store: newStore, appStore: store)
        let hostingCtrl = NSHostingController(rootView: playerView)
        let window = PlayerWindow(contentViewController: hostingCtrl)
        #if DEBUG
        DebugLogManager.shared?.append("[App] player 창 생성 \(ObjectIdentifier(window).hashValue)")
        #endif
        window.title = playerItem.title
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        if let docButton = window.standardWindowButton(.documentIconButton) {
            docButton.isHidden = false
            docButton.image = WindowFactory.icon("play.fill")
        }
        // close() 시 창을 즉시 해제한다(NSWindow 기본 동작). false로 두면 닫힌 창이
        // NSApp.windows에 강참조로 잔존해 Window→HostingController→PlayerView→MPVClient
        // 체인 전체가 재생마다 누적된다. (T-1208)
        window.isReleasedWhenClosed = true
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
            movableByBackground: true,
            titlebarIcon: WindowFactory.icon("ladybug.fill")
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
        // isReleasedWhenClosed=true이므로 close() 후 AppKit이 창과 뷰트리를 정리한다.
        // AppDelegate 참조만 끊는다. (T-1208)
        playerWindow = nil
        #if DEBUG
        DebugLogManager.shared?.append(
            "[App] player 창 닫힘 — NSApp.windows 잔존: \(NSApp.windows.compactMap { $0.identifier?.rawValue ?? ($0 is PlayerWindow ? "player(id없음)" : nil) })"
        )
        #endif
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
