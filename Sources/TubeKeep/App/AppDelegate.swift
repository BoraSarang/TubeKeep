import Cocoa
import SwiftUI
import ComposableArchitecture
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }
    private var statusIconView: NSImageView!
    private var statusLabel1: NSTextField!
    private var statusLabel2: NSTextField!
    private let statusBarHeight: CGFloat = 22
    private var videoDownloaderWindow: NSWindow?
    private var libraryWindowController: FixedWidthWindowController?
    private var lastMenuState: (active: Int, completed: Int, total: Int, speed: String, eta: String)?
    private var menuActiveItem: NSMenuItem?
    private var menuCompletedItem: NSMenuItem?
    private var menuPendingItem: NSMenuItem?
    private var menuETAItem: NSMenuItem?
    private var menuQueueSeparator: NSMenuItem?
    private var hasQueueSection = false
    #if DEBUG
    private var libraryLogManager: DebugLogManager?
    private var downloaderLogManager: DebugLogManager?
    private var batchLogManager: DebugLogManager?
    private var channelLogManager: DebugLogManager?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.send(.appDidFinishLaunching)

        // Request notification permission for channel update alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("알림 권한 요청 실패: \(error)") }
        }

        setupStatusBar()

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

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
                self.openSettingsWindow()
                return nil
            }
            return event
        }

        DispatchQueue.main.async {
            self.migrateLibraryData()

            // Restore security-scoped bookmark for storage directory
            BookmarkManager.ensureAccess()

            if let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
               let data = json.data(using: .utf8),
               let settings = try? JSONDecoder().decode(Settings.self, from: data),
               !settings.showMainWindowOnLaunch {
                // 설정에서 메인창 자동 표시가 꺼져있으면 열지 않음
            } else {
                self.openMainWindow()
            }
            self.startClipboardMonitoring()
        }
    }

    private func migrateLibraryData() {
        let saveKey = "downloadLibrary"
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupSuiteName)
        guard sharedDefaults?.data(forKey: saveKey) == nil,
              let data = UserDefaults.standard.data(forKey: saveKey)
        else { return }
        sharedDefaults?.set(data, forKey: saveKey)
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
            if let img = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "TubeKeep") {
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

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateStatusBarText()
            let s = self.store.state.statusBar
            let shouldHaveSection = s.hasActiveDownloads || s.activeCount > 0

            if shouldHaveSection != self.hasQueueSection {
                self.hasQueueSection = shouldHaveSection
                self.rebuildMenu()
                return
            }

            if shouldHaveSection, self.menuActiveItem != nil {
                let active = s.activeCount
                let completed = s.completedCount
                let pending = s.totalCount - active - completed
                let speed = s.downloadSpeed.isEmpty ? "" : " · \(s.downloadSpeed)"

                self.menuActiveItem?.title = active > 0 ? "다운로드 중: \(active)개\(speed)" : "다운로드 중: 0개"
                self.menuCompletedItem?.title = completed > 0 ? "완료: \(completed)개" : "완료: 0개"
                self.menuPendingItem?.title = pending > 0 ? "대기: \(pending)개" : "대기: 0개"
                self.menuETAItem?.title = s.downloadETA.isEmpty
                    ? "남은 시간: --"
                    : "남은 시간: \(s.downloadETA)"

                // Force live update while menu is open (menu tracking uses .eventTracking run loop)
                self.menuActiveItem?.menu?.itemChanged(self.menuActiveItem!)
                self.menuCompletedItem?.menu?.itemChanged(self.menuCompletedItem!)
                self.menuPendingItem?.menu?.itemChanged(self.menuPendingItem!)
                self.menuETAItem?.menu?.itemChanged(self.menuETAItem!)
            }
        }
        RunLoop.main.add(timer, forMode: .common)

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
        } else if !s.statusText.isEmpty, s.statusText != "대기중" {
            statusLabel1.alignment = .center
            statusLabel1.stringValue = s.statusText
            statusLabel2.alignment = .center
            statusLabel2.stringValue = s.statusDetail.isEmpty
                ? (s.badgeCount > 0 ? "새 영상 \(s.badgeCount)개 채널" : "")
                : s.statusDetail
        } else if s.completedCount > 0 {
            statusLabel1.alignment = .center
            statusLabel1.stringValue = "다운로드"
            statusLabel2.alignment = .center
            statusLabel2.stringValue = "완료 \(s.completedCount)/\(s.totalCount)"
        } else {
            statusLabel1.alignment = .center
            statusLabel1.stringValue = "다운로드"
            statusLabel2.alignment = .center
            statusLabel2.stringValue = s.badgeCount > 0 ? "대기중 \(s.badgeCount)" : "대기중"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let libraryItem = NSMenuItem(title: "튜브킵", action: #selector(openMainWindow), keyEquivalent: "")
        libraryItem.target = self
        menu.addItem(libraryItem)
        menu.addItem(NSMenuItem.separator())
        let videoItem = NSMenuItem(title: "영상 다운로더", action: #selector(openVideoDownloaderWindow), keyEquivalent: "")
        videoItem.target = self
        menu.addItem(videoItem)
        let batchItem = NSMenuItem(title: "일괄 다운로더", action: #selector(openBatchDownloadWindow), keyEquivalent: "")
        batchItem.target = self
        menu.addItem(batchItem)
        let channelItem = NSMenuItem(title: "채널 다운로더", action: #selector(openChannelDownloaderWindow), keyEquivalent: "")
        channelItem.target = self
        menu.addItem(channelItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "인터넷 속도 측정",
            action: #selector(startSpeedTest),
            keyEquivalent: ""
        ))

        if store.state.statusBar.hasActiveDownloads || store.state.statusBar.activeCount > 0 {
            let sep = NSMenuItem.separator()
            menu.addItem(sep)
            menuQueueSeparator = sep
            let sb = store.state.statusBar

            let activeTitle = sb.activeCount > 0
                ? "다운로드 중: \(sb.activeCount)개\(sb.downloadSpeed.isEmpty ? "" : " · \(sb.downloadSpeed)")"
                : "다운로드 중: 0개"
            menuActiveItem = NSMenuItem(title: activeTitle, action: nil, keyEquivalent: "")
            menuActiveItem?.isEnabled = false
            menu.addItem(menuActiveItem!)

            let completedTitle = sb.completedCount > 0 ? "완료: \(sb.completedCount)개" : "완료: 0개"
            menuCompletedItem = NSMenuItem(title: completedTitle, action: nil, keyEquivalent: "")
            menuCompletedItem?.isEnabled = false
            menu.addItem(menuCompletedItem!)

            let pending = sb.totalCount - sb.activeCount - sb.completedCount
            let pendingTitle = pending > 0 ? "대기: \(pending)개" : "대기: 0개"
            menuPendingItem = NSMenuItem(title: pendingTitle, action: nil, keyEquivalent: "")
            menuPendingItem?.isEnabled = false
            menu.addItem(menuPendingItem!)

            let etaTitle = sb.downloadETA.isEmpty ? "남은 시간: --" : "남은 시간: \(sb.downloadETA)"
            menuETAItem = NSMenuItem(title: etaTitle, action: nil, keyEquivalent: "")
            menuETAItem?.isEnabled = false
            menu.addItem(menuETAItem!)
        } else {
            menuQueueSeparator = nil
            menuActiveItem = nil
            menuCompletedItem = nil
            menuPendingItem = nil
            menuETAItem = nil
        }

        #if DEBUG
        menu.addItem(NSMenuItem.separator())
        let mockSubmenu = NSMenu()
        mockSubmenu.addItem(NSMenuItem(
            title: "상태바 테스트",
            action: #selector(startStatusBarMockTest),
            keyEquivalent: ""
        ))
        mockSubmenu.addItem(NSMenuItem(
            title: "채널 업데이트 (DEBUG)",
            action: #selector(triggerChannelUpdate),
            keyEquivalent: ""
        ))
        let mockItem = NSMenuItem(title: "Mock 테스트", action: nil, keyEquivalent: "")
        mockItem.submenu = mockSubmenu
        menu.addItem(mockItem)
        #endif
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(
            title: "설정...",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(
            title: "정보",
            action: #selector(openAboutWindow),
            keyEquivalent: ""
        ))
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
        let badgeCount = store.state.statusBar.badgeCount
        if badgeCount > 0 {
            store.send(.statusBar(.badgeReset))
            let channelsWithNew = ChannelDownloadCache.allChannelsWithNewVideos
            if let firstChannelId = channelsWithNew.first {
                pendingChannelId = firstChannelId
            }
            openChannelDownloaderWindow()
        } else {
            openMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rebuildMenu()
        }
    }

    // MARK: - Library Window

    @objc func openMainWindow() {
        if let controller = libraryWindowController, let window = controller.window {
            #if DEBUG
            libraryLogManager?.append("TubeKeep 창: 기존 창 재사용 (activate)")
            #endif
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        #if DEBUG
        let logManager = DebugLogManager()
        DebugLogManager.shared = logManager
        libraryLogManager = logManager
        logManager.append("TubeKeep 창 생성")
        let rootView = MainView(store: store)
            .debugLogOverlay(manager: logManager)
        #else
        let rootView = MainView(store: store)
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
        #if DEBUG
        logManager.append("TubeKeep 창: makeKeyAndOrderFront + NSApp.activate")
        #endif
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

    @objc private func triggerChannelUpdate() {
        let fetchService = ChannelFetchService()
        Task { await self.checkChannelUpdates(fetchService: fetchService) }
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

    @objc func openVideoDownloaderWindow() {
        if let window = videoDownloaderWindow {
            #if DEBUG
            downloaderLogManager?.append("영상 다운로더: 기존 창 재사용 (activate)")
            #endif
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        dismissClipboardNotification()
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
        #if DEBUG
        logManager.append("영상 다운로더 창: makeKeyAndOrderFront + NSApp.activate")
        #endif
    }

    @objc private func openBatchDownloadWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "batch"
        }) {
            #if DEBUG
            batchLogManager?.append("일괄 다운로더: 기존 창 재사용 (activate)")
            #endif
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        dismissClipboardNotification()
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
        #if DEBUG
        logManager.append("일괄 다운로더 창: makeKeyAndOrderFront + NSApp.activate")
        #endif
    }

    @objc func openChannelDownloaderWindow() {
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "channel"
        }) {
            #if DEBUG
            channelLogManager?.append("채널 다운로더: 기존 창 재사용 (activate)")
            #endif
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            // Forward data to existing window via separate notification to avoid recursion
            if let data = pendingChannelData {
                #if DEBUG
                channelLogManager?.append("채널 다운로더: pendingChannelData 전달 → selectChannelNotification")
                #endif
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

        dismissClipboardNotification()
        dismissSpeedTestToast()

        #if DEBUG
        let logManager = DebugLogManager()
        channelLogManager = logManager
        logManager.append("채널 다운로더 창 생성 (pendingChannelId=\(pendingChannelId ?? "nil"), pendingData=\(pendingChannelData != nil))")
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
        #if DEBUG
        logManager.append("채널 다운로더 창: makeKeyAndOrderFront + NSApp.activate")
        #endif
    }

    @objc private func openChannelDownloaderFromNotification(_ notification: Notification) {
        let info = (notification.userInfo as? [String: Any]) ?? [:]
        #if DEBUG
        channelLogManager?.append("openChannelDownloaderFromNotification: channelId=\(info["channelId"] ?? "nil")")
        #endif
        pendingChannelData = info
        pendingChannelId = info["channelId"] as? String
        openChannelDownloaderWindow()
    }

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

    private var settingsWindow: NSWindow?

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

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
            DispatchQueue.main.async {
                self.showClipboardNotification(url: url)
            }
        }

        startChannelUpdateCheck()
    }

    private func startChannelUpdateCheck() {
        let fetchService = ChannelFetchService()
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.checkChannelUpdates(fetchService: fetchService) }
        }
        // Also check shortly after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            Task { await self.checkChannelUpdates(fetchService: fetchService) }
        }
    }

    private func checkChannelUpdates(fetchService: ChannelFetchService) async {
        let channels = SubscribedChannel.loadAll()
        guard !channels.isEmpty else {
            #if DEBUG
            libraryLogManager?.append("채널 업데이트 체크: 저장된 채널 없음")
            #endif
            return
        }

        #if DEBUG
        libraryLogManager?.append("🔄 채널 업데이트 체크 시작 (\(channels.count)개)")
        #endif
        _ = await MainActor.run { [channels] in
            self.store.send(.statusBar(.updateStatusText("업데이트 확인 중")))
            self.store.send(.statusBar(.updateStatusDetail("[0/\(channels.count)]")))
        }

        var hasChanges = false
        var newVideosByChannel: [(channelId: String, channelName: String, count: Int, videoIds: [String])] = []

        for (i, channel) in channels.enumerated() {
            let detail = "[\(i+1)/\(channels.count)]"
            _ = await MainActor.run { [detail] in
                self.store.send(.statusBar(.updateStatusDetail(detail)))
            }
            #if DEBUG
            libraryLogManager?.append("  채널 체크: \(channel.name) (\(i+1)/\(channels.count))")
            #endif

            let lastFetch = ChannelDownloadCache.lastFetchDate(channelId: channel.id)
            let minInterval: TimeInterval = 3600
            guard Date().timeIntervalSince(lastFetch) >= minInterval else {
                #if DEBUG
                libraryLogManager?.append("    ⏭ 1시간 이내 fetch 완료, skip")
                #endif
                continue
            }

            guard let result = try? await fetchService.fetchAllVideos(
                channelId: channel.id, handle: channel.handle
            ) else {
                #if DEBUG
                libraryLogManager?.append("    ❌ fetch 실패")
                #endif
                continue
            }
            ChannelDownloadCache.markFetchDate(channelId: channel.id)

            let downloadedIDs = ChannelDownloadCache.loadDownloadedIDs(channelName: channel.name)
            let seenIDs = Set(ChannelDownloadCache.loadSeenVideoIds(channelId: channel.id))
            let newVideos = result.videos.filter {
                !downloadedIDs.contains($0.id) && !seenIDs.contains($0.id)
            }
            if !newVideos.isEmpty {
                hasChanges = true
                let videoIds = newVideos.map { $0.id }
                newVideosByChannel.append((channel.id, channel.name, newVideos.count, videoIds))
                ChannelDownloadCache.saveNewVideoIds(channelId: channel.id, videoIds: videoIds)
                #if DEBUG
                libraryLogManager?.append("    ✅ 새 영상 \(newVideos.count)개 발견")
                #endif
            } else {
                #if DEBUG
                libraryLogManager?.append("    ➖ 새 영상 없음")
                #endif
            }
        }

        let updatedChannels = ChannelDownloadCache.allChannelsWithNewVideos
        let notifyHasChanges = hasChanges
        let notifyTotal = newVideosByChannel.reduce(0) { $0 + $1.count }
        let notifyDetails = newVideosByChannel.map { ($0.channelName, $0.count) }
        _ = await MainActor.run {
            if notifyHasChanges {
                self.store.send(.statusBar(.updateStatusText("업데이트 완료")))
                self.store.send(.statusBar(.updateStatusDetail("새 영상 \(notifyTotal)개")))
                self.showChannelUpdateNotification(total: notifyTotal, details: notifyDetails)
                self.store.send(.statusBar(.setBadgeCount(updatedChannels.count)))
            } else {
                self.store.send(.statusBar(.updateStatusText("업데이트 확인")))
                self.store.send(.statusBar(.updateStatusDetail("새 영상 없음")))
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.store.send(.statusBar(.updateStatusText("")))
            self?.store.send(.statusBar(.updateStatusDetail("")))
        }
        #if DEBUG
        libraryLogManager?.append("✅ 채널 업데이트 체크 완료 (새 영상 채널 \(updatedChannels.count)개)")
        #endif
    }

    private func showChannelUpdateNotification(total: Int, details: [(channelName: String, count: Int)]) {
        let content = UNMutableNotificationContent()
        content.title = "새 영상 알림"
        content.body = details.map { "\($0.channelName): \($0.count)개" }.joined(separator: "\n")
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 전송 실패: \(error)")
            }
        }
    }

    private var pendingChannelId: String?
    private var pendingChannelData: [String: Any]?

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
                self.openVideoDownloaderWindow()
                self.store.send(.home(.autoFetchInfo(url)))
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

        return false
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


