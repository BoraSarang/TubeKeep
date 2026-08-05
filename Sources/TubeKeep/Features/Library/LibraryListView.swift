import SwiftUI
import ComposableArchitecture

struct LibraryListView: View {
    let store: StoreOf<AppReducer>
    @State private var thumbnailImages: [String: NSImage] = [:]

    var body: some View {
        VStack(spacing: 0) {
            sortBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            if !store.library.selectedIds.isEmpty {
                selectionBar
                Divider()
            }

            if let channelId = store.library.selectedChannel,
               store.library.filterMode == .all,
               let first = store.library.items.first(where: { $0.channelId == channelId }) {
                ChannelHeaderView(channelId: channelId, channelName: first.channelName, items: store.library.items, store: store)
                Divider()
            }

            if store.library.items.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.library.filteredItems.isEmpty {
                searchEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        }
    }

    private var sortBar: some View {
        HStack {
            Text("\(store.library.filteredItems.count)개 항목")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.send(.library(.toggleThumbnailPreview))
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 11))
                    .foregroundStyle(store.library.showThumbnailPreview ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(store.library.showThumbnailPreview ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help(store.library.showThumbnailPreview ? "썸네일 미리보기 끄기" : "썸네일 미리보기 켜기")

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
            store.send(.library(.setViewMode(.grid)))
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .help("그리드 보기")
    }

    private var selectionBar: some View {
        HStack {
            Text("\(store.library.selectedIds.count)개 선택됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)

            Spacer()

            Button {
                store.send(.library(.selectAll))
            } label: {
                Image(systemName: "checkmark.circle")
                Text("전체 선택")
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button {
                store.send(.library(.revealSelectedInFinder))
            } label: {
                Image(systemName: "folder")
                Text("Finder에서 보기")
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button {
                store.send(.library(.openSelected))
            } label: {
                Image(systemName: "play.fill")
                Text("열기")
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

            Button {
                store.send(.library(.removeSelected))
            } label: {
                Image(systemName: "trash")
                Text("선택 삭제")
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

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

    private var searchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("검색 결과가 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
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

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let snippetMap = Dictionary(uniqueKeysWithValues: store.library.searchResults.compactMap { result in
                    result.snippet.map { (result.item.id, $0) }
                })
                ForEach(store.library.filteredItems) { item in
                    LibraryListRow(
                        item: item,
                        thumbnail: thumbnailImages[item.id],
                        snippet: snippetMap[item.id],
                        isSelected: store.library.selectedIds.contains(item.id),
                        hasSubtitles: store.library.subtitleAvailableIds.contains(item.id),
                        hasPodcast: store.library.podcast.availableIds.contains(item.id),
                        onOpen: { store.send(.library(.openFile(item.id))) },
                        onReveal: { store.send(.library(.revealInFinder(item.id))) },
                        onDelete: { store.send(.library(.removeItem(item.id))) },
                        onDownloadSubtitles: { store.send(.library(.downloadSubtitles(item.id))) },
                        onChannelDownload: { store.send(.library(.openChannelDownload(channelId: item.channelId, channelName: item.channelName))) },
                        onOpenAI: { store.send(.library(.showSummary(item.id))) },
                        onToggleSelection: { store.send(.library(.toggleSelection(item.id))) }
                    )
                    .onAppear {
                        loadThumbnail(for: item)
                    }
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
    }

    private func loadThumbnail(for item: LibraryItem) {
        guard thumbnailImages[item.id] == nil else { return }
        let service = LibraryCacheService.shared

        Task {
            if let cached = service.cachedThumbnail(for: item.id) {
                await MainActor.run { thumbnailImages[item.id] = cached }
                return
            }
            if let data = await service.loadThumbnail(from: item.thumbnailURL, videoId: item.id),
               let img = NSImage(data: data) {
                await MainActor.run { thumbnailImages[item.id] = img }
            } else {
                await MainActor.run { thumbnailImages[item.id] = service.placeholderThumbnail() }
            }
        }
    }
}

private struct LibraryListRow: View {
    let item: LibraryItem
    let thumbnail: NSImage?
    let snippet: String?
    let isSelected: Bool
    let hasSubtitles: Bool
    let hasPodcast: Bool
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onDownloadSubtitles: () -> Void
    let onChannelDownload: () -> Void
    let onOpenAI: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            thumbnailView
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color(.separatorColor), lineWidth: isSelected ? 2 : 0.5)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.channelName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if hasSubtitles {
                        Image(systemName: "captions.bubble.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }

                    if let data = item.chapters,
                       let chapters = try? JSONDecoder().decode([ChapterInfo].self, from: data),
                       !chapters.isEmpty {
                        HStack(spacing: 1) {
                            Image(systemName: "list.number")
                                .font(.system(size: 9))
                            Text("\(chapters.count)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                    }

                    if item.summary != nil && !(item.summary?.isEmpty ?? true) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    }
                }

                if let snippet = snippet {
                    Text(snippet)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if let idx = item.channelUploadIndex {
                    Text("#\(String(format: "%03d", idx))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                if let d = item.duration, d > 0 {
                    Text(LibraryItem.formatDuration(d))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if let upload = item.uploadDate {
                    Text(upload.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Text("다운로드 " + item.downloadDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .leftClickMenu(entries: [
            .action(title: "열기", icon: "play.fill", action: onOpen),
            .separator,
            .action(title: "AI 기능", icon: "sparkles", action: onOpenAI),
            .separator,
            .action(title: "자막 다운로드", icon: "captions.bubble", action: onDownloadSubtitles, enabled: !hasSubtitles),
            .action(title: "채널 다운로더 실행", icon: "tv", action: onChannelDownload),
            .separator,
            .action(title: "Finder에서 보기", icon: "folder", action: onReveal),
            .separator,
            .action(title: "라이브러리에서 삭제", icon: "trash", action: onDelete, destructive: true)
        ], onToggleSelection: onToggleSelection)
    }

    private var thumbnailView: some View {
        Group {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 27)
            } else {
                Rectangle()
                    .fill(Color(.textBackgroundColor))
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10))
                    )
                    .frame(width: 48, height: 27)
            }
        }
    }
}
