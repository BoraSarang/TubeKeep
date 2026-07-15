import SwiftUI
import ComposableArchitecture

struct LibraryGridView: View {
    let store: StoreOf<AppReducer>
    @State private var thumbnailImages: [String: NSImage] = [:]
    @State private var displayedCount = 50
    private let pageSize = 50

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 300), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            sortBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            if !store.library.selectedIds.isEmpty {
                selectionBar
                Divider()
            }

            Divider()

            ScrollView {
                if store.library.items.isEmpty && store.library.filteredItems.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        let displayItems = Array(store.library.filteredItems.prefix(displayedCount))
                        ForEach(displayItems) { item in
                             LibraryGridCell(
                                 item: item,
                                 thumbnail: thumbnailImages[item.id],
                                 isSelected: store.library.selectedIds.contains(item.id),
                                 isDownloadingSubtitle: store.library.subtitleDownloadingIds.contains(item.id),
                                 hasSubtitles: store.library.subtitleAvailableIds.contains(item.id),
                                onOpen: { store.send(.library(.openFile(item.id))) },
                                onReveal: { store.send(.library(.revealInFinder(item.id))) },
                                onDelete: { store.send(.library(.removeItem(item.id))) },
                                onDownloadSubtitles: { store.send(.library(.downloadSubtitles(item.id))) },
                                onChannelDownload: { store.send(.library(.openChannelDownload(channelId: item.channelId, channelName: item.channelName))) },
                                onToggleSelection: { store.send(.library(.toggleSelection(item.id))) }
                            )
                            .onAppear {
                                loadThumbnail(for: item)
                                if item.id == displayItems.last?.id {
                                    displayedCount += pageSize
                                }
                            }
                        }
                    }
                    .padding(16)

                    EmptyLibraryCell(store: store)
                        .frame(height: 100)
                        .padding(.horizontal, 16)
                }
            }
        }
        .onChange(of: store.library.filteredItems) { _ in
            displayedCount = pageSize
            let newIds = Set(store.library.filteredItems.prefix(displayedCount).map(\.id))
            let oldIds = Set(thumbnailImages.keys)
            for id in oldIds.subtracting(newIds) {
                thumbnailImages.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            Text("\(store.library.filteredItems.count)개 항목")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Picker("정렬", selection: Binding(
                get: { store.library.sortOrder },
                set: { store.send(.library(.setSortOrder($0))) }
            )) {
                ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 11))
            .fixedSize()

            viewModeToggle
        }
    }

    private var viewModeToggle: some View {
        Button {
            store.send(.library(.setViewMode(.list)))
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .help("목록 보기")
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack {
            Text("\(store.library.selectedIds.count)개 선택됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)

            Spacer()

            Button("전체 선택") {
                store.send(.library(.selectAll))
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button("선택 해제") {
                store.send(.library(.clearSelection))
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button("선택 삭제") {
                store.send(.library(.removeSelected))
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("영상은 아래와 같은 방법으로\n다운로드 받으실 수 있습니다")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                downloaderButton("영상 다운로더", notification: Constants.openDownloaderWindowNotification)
                downloaderButton("일괄 다운로더", notification: Constants.openBatchWindowNotification)
                downloaderButton("채널 다운로더", notification: Constants.openChannelWindowNotification)
            }
        }
    }

    private func downloaderButton(_ title: String, notification: Notification.Name) -> some View {
        Button {
            NotificationCenter.default.post(name: notification, object: nil)
        } label: {
            Text(title)
                .font(.system(size: 11))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail(for item: LibraryItem) {
        guard thumbnailImages[item.id] == nil else { return }
        let service = LibraryCacheService.shared

        Task {
            if let cached = await service.cachedThumbnail(for: item.id) {
                await MainActor.run {
                    thumbnailImages[item.id] = cached
                }
                return
            }

            if let data = await service.loadThumbnail(from: item.thumbnailURL, videoId: item.id),
               let img = NSImage(data: data) {
                await MainActor.run {
                    thumbnailImages[item.id] = img
                }
            } else {
                await MainActor.run {
                    thumbnailImages[item.id] = service.placeholderThumbnail()
                }
            }
        }
    }
}

// MARK: - Grid Cell

struct LibraryGridCell: View {
    let item: LibraryItem
    let thumbnail: NSImage?
    let isSelected: Bool
    let isDownloadingSubtitle: Bool
    let hasSubtitles: Bool
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onDownloadSubtitles: () -> Void
    let onChannelDownload: () -> Void
    let onToggleSelection: () -> Void
    @State private var bounceUp = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                thumbnailView
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color(.separatorColor), lineWidth: isSelected ? 2 : 0.5)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.15))
                            }
                        }
                    )

                if isDownloadingSubtitle {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(y: bounceUp ? -3 : 3)

                        Text("자막")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            bounceUp = true
                        }
                    }
                } else if hasSubtitles {
                    HStack(spacing: 3) {
                        Image(systemName: "captions.bubble")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)

                        Text("자막")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
            }

            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .truncationMode(.tail)

            Text(item.channelName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(spacing: 2) {
                if let upload = item.uploadDate {
                    Text("UP:" + upload.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Text(",")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
                Text("DN:" + item.downloadDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .leftClickMenu(entries: [
            .action(title: "열기", action: onOpen),
            .separator,
            .action(title: "자막 다운로드", action: onDownloadSubtitles, enabled: !hasSubtitles && !isDownloadingSubtitle),
            .action(title: "채널 다운로더 실행", action: onChannelDownload),
            .separator,
            .action(title: "Finder에서 보기", action: onReveal),
            .separator,
            .action(title: "라이브러리에서 삭제", action: onDelete, destructive: true)
        ], onToggleSelection: onToggleSelection)
        .onHover { hovering in
            isHovering = hovering
        }
        .background(HoverPreviewPanel(thumbnail: thumbnail, isVisible: $isHovering))
    }

    private var thumbnailView: some View {
        Color.clear
            .overlay {
                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.textBackgroundColor))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let idx = item.channelUploadIndex {
                    Text("#\(String(format: "%03d", idx))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let d = item.duration, d > 0 {
                    Text(LibraryItem.formatDuration(d))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()
    }
}

// MARK: - Empty Cell

struct EmptyLibraryCell: View {
    let store: StoreOf<AppReducer>

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)

            Text("다음 방법으로 영상을 다운로드할 수 있습니다")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()

            Button("영상 다운로더") {
                NotificationCenter.default.post(name: Constants.openDownloaderWindowNotification, object: nil)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)

            Button("일괄 다운로더") {
                NotificationCenter.default.post(name: Constants.openBatchWindowNotification, object: nil)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)

            Button("채널 다운로더") {
                NotificationCenter.default.post(name: Constants.openChannelWindowNotification, object: nil)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Left-Click NSMenu

enum LeftClickMenuEntry {
    case action(title: String, action: () -> Void, destructive: Bool = false, enabled: Bool = true)
    case separator
}

struct LeftClickMenu: NSViewRepresentable {
    let entries: [LeftClickMenuEntry]
    let onToggleSelection: (() -> Void)?

    init(entries: [LeftClickMenuEntry], onToggleSelection: (() -> Void)? = nil) {
        self.entries = entries
        self.onToggleSelection = onToggleSelection
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(click)
        return view
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.entries = entries
        context.coordinator.onToggleSelection = onToggleSelection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(entries: entries, onToggleSelection: onToggleSelection)
    }

    class Coordinator: NSObject {
        var entries: [LeftClickMenuEntry] = []
        var onToggleSelection: (() -> Void)?

        init(entries: [LeftClickMenuEntry], onToggleSelection: (() -> Void)?) {
            self.entries = entries
            self.onToggleSelection = onToggleSelection
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let modifiers = NSApp.currentEvent?.modifierFlags ?? []

            if modifiers.contains(.command) {
                onToggleSelection?()
                return
            }

            let menu = NSMenu()
            menu.autoenablesItems = false
            for (i, entry) in entries.enumerated() {
                switch entry {
                case .action(let title, _, let destructive, let enabled):
                    let item = NSMenuItem(title: title, action: enabled ? #selector(performAction(_:)) : nil, keyEquivalent: "")
                    item.tag = i
                    item.target = self
                    item.isEnabled = enabled
                    if destructive {
                        item.attributedTitle = NSAttributedString(
                            string: title,
                            attributes: [.foregroundColor: NSColor.red]
                        )
                    }
                    menu.addItem(item)
                case .separator:
                    menu.addItem(.separator())
                }
            }
            let point = gesture.location(in: view)
            menu.popUp(positioning: nil, at: point, in: view)
        }

        @objc func performAction(_ sender: NSMenuItem) {
            let idx = sender.tag
            guard idx >= 0, idx < entries.count else { return }
            if case .action(_, let action, _, _) = entries[idx] {
                action()
            }
        }
    }
}

extension View {
    func leftClickMenu(entries: [LeftClickMenuEntry]) -> some View {
        self.overlay(LeftClickMenu(entries: entries))
    }

    func leftClickMenu(entries: [LeftClickMenuEntry], onToggleSelection: @escaping () -> Void) -> some View {
        self.overlay(LeftClickMenu(entries: entries, onToggleSelection: onToggleSelection))
    }
}

// MARK: - Hover Preview Panel (NSViewRepresentable + SwiftUI .onHover)

struct HoverPreviewPanel: NSViewRepresentable {
    nonisolated(unsafe) static var isSuppressed = false

    let thumbnail: NSImage?
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.positioningView = nsView
        context.coordinator.thumbnail = thumbnail
        if isVisible {
            context.coordinator.showPanel()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSWindowDelegate {
        weak var positioningView: NSView?
        var thumbnail: NSImage?
        var panel: NSPanel?
        var hostingView: NSView?
        var checkTimer: Timer?
        var globalMonitor: Any?
        private var lastHideTime: Date = .distantPast

        func showPanel() {
            guard let positioningView, panel == nil else { return }
            guard Date().timeIntervalSince(lastHideTime) > 0.3 else { return }
            let content = NSHostingView(rootView: previewContent)
            content.frame = CGRect(x: 0, y: 0, width: 360, height: 203)

            let newPanel = NSPanel(
                contentRect: CGRect(x: 0, y: 0, width: 360, height: 203),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.contentViewController = NSViewController()
            newPanel.contentViewController?.view = content
            newPanel.delegate = self

            if let window = positioningView.window {
                let windowRect = positioningView.convert(positioningView.bounds, to: nil)
                let screenRect = window.convertToScreen(windowRect)
                let centerX = screenRect.midX
                let centerY = screenRect.maxY - (screenRect.width * 9 / 32)
                newPanel.setFrame(CGRect(x: centerX - 360, y: centerY, width: 360, height: 203), display: true)
                window.addChildWindow(newPanel, ordered: .above)
            }

            panel = newPanel
            hostingView = content

            // Monitor scroll/click outside the app to dismiss
            if let monitor = globalMonitor {
                NSEvent.removeMonitor(monitor)
                globalMonitor = nil
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.hidePanel()
            }

            // Timer: track cell position, hide only when mouse leaves cell AND panel
            checkTimer?.invalidate()
            checkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
                guard let self = self,
                      let positioningView = self.positioningView,
                      let window = positioningView.window,
                      let panel = self.panel else {
                    self?.hidePanel()
                    timer.invalidate()
                    self?.checkTimer = nil
                    return
                }

                if HoverPreviewPanel.isSuppressed {
                    self.hidePanel()
                    timer.invalidate()
                    self.checkTimer = nil
                    return
                }

                let mouseLoc = NSEvent.mouseLocation
                let windowRect = positioningView.convert(positioningView.bounds, to: nil)
                let currentCellFrame = window.convertToScreen(windowRect)

                let thumbnailCenterX = currentCellFrame.midX
                let thumbnailCenterY = currentCellFrame.maxY - (currentCellFrame.width * 9 / 32)
                let newX = thumbnailCenterX - 360
                let newY = thumbnailCenterY
                panel.setFrameOrigin(NSPoint(x: newX, y: newY))

                let panelFrame = panel.frame
                // Keep visible if mouse is in cell OR in the preview panel
                if !currentCellFrame.contains(mouseLoc) && !panelFrame.contains(mouseLoc) {
                    self.hidePanel()
                    timer.invalidate()
                    self.checkTimer = nil
                }
            }
            if let t = checkTimer { RunLoop.main.add(t, forMode: .common) }
        }

        func hidePanel() {
            lastHideTime = Date()
            checkTimer?.invalidate()
            checkTimer = nil
            if let monitor = globalMonitor {
                NSEvent.removeMonitor(monitor)
                globalMonitor = nil
            }
            panel?.orderOut(nil)
            panel = nil
            hostingView = nil
        }

        func windowWillClose(_ notification: Notification) {
            panel = nil
            hostingView = nil
        }

        @ViewBuilder
        var previewContent: some View {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 360, height: 203)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separatorColor), lineWidth: 1.5)
                    )
            } else {
                Rectangle()
                    .fill(Color(.textBackgroundColor))
                    .frame(width: 360, height: 203)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 24))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separatorColor), lineWidth: 1.5)
                    )
            }
        }
    }
}
