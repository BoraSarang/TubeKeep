import Cocoa
import ComposableArchitecture

@MainActor
final class StatusBarManager {
    let statusItem: NSStatusItem
    private let store: StoreOf<AppReducer>
    private var statusIconView: NSImageView!
    private var statusLabel1: NSTextField!
    private var statusLabel2: NSTextField!
    private let statusBarHeight: CGFloat = 22
    private var menuActiveItem: NSMenuItem?
    private var menuCompletedItem: NSMenuItem?
    private var menuPendingItem: NSMenuItem?
    private var menuETAItem: NSMenuItem?
    private var menuQueueSeparator: NSMenuItem?
    private var hasQueueSection = false
    private var queueTimer: Timer?

    var onOpenMainWindow: (() -> Void)?
    var onOpenVideoDownloader: (() -> Void)?
    var onOpenBatchDownload: (() -> Void)?
    var onOpenChannelDownloader: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenAbout: (() -> Void)?

    var onOpenBuyMeACoffee: (() -> Void)?

    #if DEBUG
    var onToggleDebugPanel: (() -> Void)?
    #endif

    init(store: StoreOf<AppReducer>) {
        self.store = store
        let totalWidth: CGFloat = 88
        self.statusItem = NSStatusBar.system.statusItem(withLength: totalWidth)
        setupStatusBar()
        startQueuePolling()
        observeAppearanceChanges()
    }

    private func setupStatusBar() {
        let iconW: CGFloat = 14
        let totalWidth: CGFloat = 88
        statusItem.button?.frame = NSRect(x: 0, y: 0, width: totalWidth, height: statusBarHeight)
        statusItem.button?.action = #selector(statusBarLeftClicked)
        statusItem.button?.target = self

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
        statusItem.button?.addSubview(container)

        rebuildMenu()
        updateStatusBarText()
    }

    private func startQueuePolling() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
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
                    let speed = s.downloadSpeed.isEmpty ? "" : " \u{00B7} \(s.downloadSpeed)"

                    self.menuActiveItem?.title = active > 0 ? "다운로드 중: \(active)개\(speed)" : "다운로드 중: 0개"
                    self.menuCompletedItem?.title = completed > 0 ? "완료: \(completed)개" : "완료: 0개"
                    self.menuPendingItem?.title = pending > 0 ? "대기: \(pending)개" : "대기: 0개"
                    self.menuETAItem?.title = s.downloadETA.isEmpty
                        ? "남은 시간: --"
                        : "남은 시간: \(s.downloadETA)"

                    self.menuActiveItem?.menu?.itemChanged(self.menuActiveItem!)
                    self.menuCompletedItem?.menu?.itemChanged(self.menuCompletedItem!)
                    self.menuPendingItem?.menu?.itemChanged(self.menuPendingItem!)
                    self.menuETAItem?.menu?.itemChanged(self.menuETAItem!)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        queueTimer = timer
    }

    private func observeAppearanceChanges() {
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
        } else if !s.statusText.isEmpty, s.statusText != "대기 중" {
            statusLabel1.alignment = .right
            statusLabel1.stringValue = s.statusText
            statusLabel2.alignment = .right
            statusLabel2.stringValue = s.statusDetail.isEmpty
                ? (s.badgeCount > 0 ? "새 영상 \(s.badgeCount)개 채널" : "")
                : s.statusDetail
        } else if s.completedCount > 0 {
            statusLabel1.alignment = .right
            statusLabel1.stringValue = "다운로드"
            statusLabel2.alignment = .right
            statusLabel2.stringValue = "완료 \(s.completedCount)/\(s.totalCount)"
        } else {
            statusLabel1.alignment = .right
            statusLabel1.stringValue = "다운로드"
            statusLabel2.alignment = .right
            statusLabel2.stringValue = s.badgeCount > 0 ? "대기 중 \(s.badgeCount)" : "대기 중"
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let libraryItem = NSMenuItem(title: "🎬 튜브킵", action: #selector(openMainWindow), keyEquivalent: "")
        libraryItem.target = self
        menu.addItem(libraryItem)
        menu.addItem(NSMenuItem.separator())
        let videoItem = NSMenuItem(title: "⬇️ 영상 다운로더", action: #selector(openVideoDownloaderWindow), keyEquivalent: "")
        videoItem.target = self
        menu.addItem(videoItem)
        let batchItem = NSMenuItem(title: "📦 일괄 다운로더", action: #selector(openBatchDownloadWindow), keyEquivalent: "")
        batchItem.target = self
        menu.addItem(batchItem)
        let channelItem = NSMenuItem(title: "📺 채널 다운로더", action: #selector(openChannelDownloaderWindow), keyEquivalent: "")
        channelItem.target = self
        menu.addItem(channelItem)
        menu.addItem(NSMenuItem.separator())

        if store.state.statusBar.hasActiveDownloads || store.state.statusBar.activeCount > 0 {
            let sep = NSMenuItem.separator()
            menu.addItem(sep)
            menuQueueSeparator = sep
            let sb = store.state.statusBar

            let activeTitle = sb.activeCount > 0
                ? "다운로드 중: \(sb.activeCount)개\(sb.downloadSpeed.isEmpty ? "" : " \u{00B7} \(sb.downloadSpeed)")"
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
        let debugItem = NSMenuItem(title: "🐛 Debug", action: nil, keyEquivalent: "")
        let debugMenu = NSMenu(title: "Debug")
        debugMenu.addItem(withTitle: "Show/Hide Debug Panel", action: #selector(toggleDebugPanel), keyEquivalent: "d")
        debugMenu.addItem(.separator())
        debugMenu.addItem(withTitle: "Copy Selection", action: #selector(debugCopySelection), keyEquivalent: "c")
        debugMenu.addItem(withTitle: "Copy All for Agent", action: #selector(debugCopyAll), keyEquivalent: "a")
        debugMenu.addItem(withTitle: "Clear Logs", action: #selector(debugClear), keyEquivalent: "k")
        debugMenu.addItem(.separator())
        debugMenu.addItem(withTitle: "Auto Scroll (📌)", action: #selector(debugToggleAutoScroll), keyEquivalent: "s")
        for item in debugMenu.items { item.target = self }
        debugItem.submenu = debugMenu
        menu.addItem(debugItem)
        #endif

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(
            title: "⚙️ 설정...",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
        let infoItem = NSMenuItem(
            title: "ℹ️ 정보",
            action: #selector(openAboutWindow),
            keyEquivalent: ""
        )
        infoItem.target = self
        menu.addItem(infoItem)
        menu.addItem(NSMenuItem.separator())
        let coffeeItem = NSMenuItem(
            title: "☕ 후원하기",
            action: #selector(openBuyMeACoffee),
            keyEquivalent: ""
        )
        coffeeItem.target = self
        menu.addItem(coffeeItem)
        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func statusBarLeftClicked() {
        statusItem.menu = nil
        let badgeCount = store.state.statusBar.badgeCount
        if badgeCount > 0 {
            store.send(.statusBar(.badgeReset))
            let channelsWithNew = ChannelDownloadCache.allChannelsWithNewVideos
            if let firstChannelId = channelsWithNew.first {
                onOpenChannelDownloader?()
                _ = firstChannelId
            } else {
                onOpenChannelDownloader?()
            }
        } else {
            onOpenMainWindow?()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rebuildMenu()
        }
    }

    // MARK: - Menu Actions

    @objc private func openMainWindow() { onOpenMainWindow?() }
    @objc private func openVideoDownloaderWindow() { onOpenVideoDownloader?() }
    @objc private func openBatchDownloadWindow() { onOpenBatchDownload?() }
    @objc private func openChannelDownloaderWindow() { onOpenChannelDownloader?() }
    @objc private func openSettingsWindow() { onOpenSettings?() }
    @objc private func openAboutWindow() { onOpenAbout?() }
    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func openBuyMeACoffee() { onOpenBuyMeACoffee?() }

    #if DEBUG
    @objc private func toggleDebugPanel() { onToggleDebugPanel?() }
    @objc private func debugCopySelection() { DebugLogManager.shared?.copySelection() }
    @objc private func debugCopyAll() { DebugLogManager.shared?.copyAll() }
    @objc private func debugClear() { DebugLogManager.shared?.clear() }
    @objc private func debugToggleAutoScroll() {
        guard let m = DebugLogManager.shared else { return }
        m.autoScroll.toggle()
    }
    #endif

}
