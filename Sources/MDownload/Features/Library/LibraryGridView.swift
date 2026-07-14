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
                                onOpen: { store.send(.library(.openFile(item.id))) },
                                onReveal: { store.send(.library(.revealInFinder(item.id))) },
                                onDelete: { store.send(.library(.removeItem(item.id))) }
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
                        .frame(height: 280)
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
            .frame(width: 100)

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
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnailView
                .aspectRatio(16 / 9, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 0.5)
                )

            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)

            Text(item.channelName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.downloadDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .leftClickMenu(entries: [
            .action(title: "열기", action: onOpen),
            .separator,
            .action(title: "Finder에서 보기", action: onReveal),
            .separator,
            .action(title: "라이브러리에서 삭제", action: onDelete, destructive: true)
        ])
    }

    private var thumbnailView: some View {
        Group {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
            } else {
                Rectangle()
                    .fill(Color(.textBackgroundColor))
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }
}

// MARK: - Empty Cell

struct EmptyLibraryCell: View {
    let store: StoreOf<AppReducer>

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("영상은 아래와 같은 방법으로\n다운로드 받으실 수 있습니다")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Left-Click NSMenu

enum LeftClickMenuEntry {
    case action(title: String, action: () -> Void, destructive: Bool = false)
    case separator
}

struct LeftClickMenu: NSViewRepresentable {
    let entries: [LeftClickMenuEntry]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(click)
        return view
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.entries = entries
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(entries: entries)
    }

    class Coordinator: NSObject {
        var entries: [LeftClickMenuEntry] = []

        init(entries: [LeftClickMenuEntry]) {
            self.entries = entries
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let menu = NSMenu()
            menu.autoenablesItems = false
            for (i, entry) in entries.enumerated() {
                switch entry {
                case .action(let title, _, let destructive):
                    let item = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: "")
                    item.tag = i
                    item.target = self
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
            if case .action(_, let action, _) = entries[idx] {
                action()
            }
        }
    }
}

extension View {
    func leftClickMenu(entries: [LeftClickMenuEntry]) -> some View {
        self.overlay(LeftClickMenu(entries: entries))
    }
}
