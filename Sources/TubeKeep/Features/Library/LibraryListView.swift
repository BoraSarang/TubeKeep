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
        LibrarySortBar(
            itemCount: store.library.filteredItems.count,
            showThumbnailPreview: store.library.showThumbnailPreview,
            sortOrder: store.library.sortOrder,
            isGrid: false,
            onToggleThumbnailPreview: { store.send(.library(.toggleThumbnailPreview)) },
            onSetSortOrder: { store.send(.library(.setSortOrder($0))) },
            onToggleViewMode: { store.send(.library(.setViewMode(.grid))) }
        )
    }

    private var selectionBar: some View {
        SelectionBar(
            count: store.library.selectedIds.count,
            isAllSelected: !store.library.selectedIds.isEmpty && store.library.selectedIds.count == store.library.filteredItems.count,
            onToggleSelectAll: { store.send(.library(.selectAll)) },
            onClearSelection: { store.send(.library(.clearSelection)) },
            onReveal: { store.send(.library(.revealSelectedInFinder)) },
            onOpen: { store.send(.library(.openSelected)) },
            onDelete: { store.send(.library(.removeSelected)) }
        )
    }

    private var emptyState: some View {
        EmptyStateView(icon: "tray", title: "영상은 아래와 같은 방법으로\n다운로드 받으실 수 있습니다") {
            HStack(spacing: 8) {
                downloaderButton("영상 다운로더", notification: Constants.openDownloaderWindowNotification)
                downloaderButton("일괄 다운로더", notification: Constants.openBatchWindowNotification)
                downloaderButton("채널 다운로더", notification: Constants.openChannelWindowNotification)
            }
        }
    }

    private var searchEmptyState: some View {
        EmptyStateView(icon: "magnifyingglass", title: "검색 결과가 없습니다")
    }

    private func downloaderButton(_ title: String, notification: Notification.Name) -> some View {
        AppPrimaryButton(title, size: .small) {
            NotificationCenter.default.post(name: notification, object: nil)
        }
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
                        onDelete: { store.send(.library(.trashItem(item.id))) },
                        onDownloadSubtitles: { store.send(.library(.downloadSubtitles(item.id))) },
                        onChannelDownload: { store.send(.library(.openChannelDownload(channelId: item.channelId, channelName: item.channelName))) },
                        onOpenAI: { store.send(.library(.showSummary(item.id))) },
                        onToggleSelection: { store.send(.library(.toggleSelection(item.id))) },
                        onPlaySnippet: snippetMap[item.id] != nil ? { store.send(.library(.playSearchMatch(item.id))) } : nil
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
    let onPlaySnippet: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            thumbnailView
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : AppColors.separator, lineWidth: isSelected ? 2 : 0.5)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(AppFont.cellTitle)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.channelName)
                        .font(AppFont.cellSubtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if hasSubtitles {
                        StatusBadge(icon: "captions.bubble.fill", color: AppColors.badgeSubtitle, style: .inline)
                    }

                    if let data = item.chapters,
                       let chapters = try? JSONDecoder().decode([ChapterInfo].self, from: data),
                       !chapters.isEmpty {
                        StatusBadge(icon: "list.number", text: "\(chapters.count)", color: AppColors.badgeChapters, style: .inline)
                    }

                    if item.summary != nil && !(item.summary?.isEmpty ?? true) {
                        StatusBadge(icon: "doc.text.fill", color: AppColors.badgeSummary, style: .inline)
                    }
                }

                if let snippet = snippet {
                    Button {
                        onPlaySnippet?()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            SnippetTextView(text: snippet)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
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
                if let pos = item.resumePosition {
                    Text("▶ " + LibraryItem.formatDuration(Int(pos)))
                        .font(AppFont.meta.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                if let upload = item.uploadDate {
                    Text(upload.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.meta)
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
            .action(title: "휴지통으로 이동", icon: "trash", action: onDelete, destructive: true)
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
                    .fill(AppColors.textBackground)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10))
                    )
                    .frame(width: 48, height: 27)
            }
        }
        .overlay(alignment: .bottom) {
            if let progress = item.resumeProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.progressTrack)
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: max(geo.size.width * progress, 2))
                    }
                }
                .frame(height: 2)
            }
        }
        .clipped()
    }
}
