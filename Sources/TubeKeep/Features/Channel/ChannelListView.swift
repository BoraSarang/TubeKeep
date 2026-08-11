import SwiftUI
import UniformTypeIdentifiers
import AppKit

private struct RowFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct ChannelDropDelegate: DropDelegate {
    let channels: [SubscribedChannel]
    let rowFrames: [Int: CGRect]
    @Binding var dragIndex: Int?
    @Binding var dropTargetIndex: Int?
    let onMove: (IndexSet, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [.text]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        guard dragIndex != nil else { return }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let _ = dragIndex else { return nil }
        let y = info.location.y
        let index = findTargetIndex(y: y)
        if dropTargetIndex != index {
            dropTargetIndex = index
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dragIndex = nil
            dropTargetIndex = nil
        }
        guard let fromIdx = dragIndex else { return false }
        let y = info.location.y
        let toIdx = findTargetIndex(y: y)
        guard fromIdx != toIdx else { return false }
        onMove(IndexSet(integer: fromIdx), toIdx > fromIdx ? toIdx + 1 : toIdx)
        return true
    }

    private func findTargetIndex(y: CGFloat) -> Int {
        if rowFrames.isEmpty { return 0 }
        let sorted = rowFrames.sorted { $0.key < $1.key }
        for (idx, frame) in sorted {
            if y < frame.midY { return idx }
        }
        return sorted.last?.key ?? 0
    }
}

struct ChannelListView: View {
    let channels: [SubscribedChannel]
    @Binding var selectedChannel: SubscribedChannel?
    let onSelect: (SubscribedChannel) -> Void
    let onAdd: () -> Void
    let onDelete: (SubscribedChannel) -> Void
    let onMoveChannels: (IndexSet, Int) -> Void

    @State private var dragIndex: Int?
    @State private var dropTargetIndex: Int?
    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var playlists: [SubscribedPlaylist] = []

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onAdd) {
                Label("채널 추가", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                            ChannelRow(
                                channel: channel,
                                isSelected: selectedChannel?.id == channel.id,
                                isDropTarget: dropTargetIndex == index
                            )
                            .id(channel.id)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(channel) }
                        .contextMenu {
                            Toggle("새 영상 알림", isOn: Binding(
                                get: { ChannelDownloadCache.isNotificationEnabled(channelId: channel.id) },
                                set: { ChannelDownloadCache.setNotificationEnabled(channelId: channel.id, enabled: $0) }
                            ))
                            Button("Finder에서 채널 폴더 열기") {
                                let folder = Constants.sanitizeFolderName(channel.name)
                                let path = "\(Constants.channelStorageDirectory)/\(folder)"
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                            }
                            Divider()
                            Button("채널 삭제") { onDelete(channel) }
                        }
                        .onDrag {
                            dragIndex = index
                            return NSItemProvider(object: channel.id as NSString)
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: RowFrameKey.self,
                                        value: [index: geo.frame(in: .named("list"))])
                            }
                        )
                        .opacity(dragIndex == index ? 0.4 : 1.0)

                        if dropTargetIndex == index {
                            Color.accentColor
                                .frame(height: 2)
                        }

                        Divider()
                    }
                }
                .padding(.horizontal, 8)
                .coordinateSpace(name: "list")
                .onPreferenceChange(RowFrameKey.self) { frames in
                    rowFrames = frames
                }
                .onDrop(
                    of: [.text],
                    delegate: ChannelDropDelegate(
                        channels: channels,
                        rowFrames: rowFrames,
                        dragIndex: $dragIndex,
                        dropTargetIndex: $dropTargetIndex,
                        onMove: onMoveChannels
                    )
                )
                .onChange(of: selectedChannel?.id) { _, newID in
                    guard let id = newID else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }

            Divider()

            playlistSection

            Divider()

            HStack {
                Image(systemName: "rectangle.3.group")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Text("등록된 채널 \(channels.count)개")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.textBackgroundColor).opacity(0.5))
        }
        .onAppear {
            playlists = SubscribedPlaylist.loadAll()
        }
    }

    // MARK: - 재생목록

    private var playlistSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("재생목록")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addPlaylist()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("재생목록 구독 추가")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            if playlists.isEmpty {
                Text("구독 중인 재생목록 없음")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            } else {
                ForEach(playlists) { playlist in
                    playlistRow(playlist)
                }
                .padding(.bottom, 6)
            }
        }
    }

    private func playlistRow(_ playlist: SubscribedPlaylist) -> some View {
        let key = SubscribedPlaylist.storageKey(for: playlist.id)
        return HStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(playlist.title)
                .font(.system(size: 11))
                .lineLimit(1)
            Spacer(minLength: 0)
            if ChannelDownloadCache.hasNewVideos(channelId: key) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
            }
            Toggle("", isOn: Binding(
                get: { ChannelDownloadCache.isNotificationEnabled(channelId: key) },
                set: { ChannelDownloadCache.setNotificationEnabled(channelId: key, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("새 영상 알림")
            Toggle("", isOn: Binding(
                get: { ChannelDownloadCache.isAutoDownloadEnabled(channelId: key) },
                set: { enabled in
                    var settings = ChannelDownloadCache.loadAutoSettings(channelId: key)
                    settings.enabled = enabled
                    ChannelDownloadCache.saveAutoSettings(channelId: key, settings: settings)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("새 영상 자동 다운로드")
            Button {
                deletePlaylist(playlist)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func addPlaylist() {
        let alert = NSAlert()
        alert.messageText = "재생목록 구독 추가"
        alert.informativeText = "YouTube 재생목록 URL을 입력하세요"
        alert.addButton(withTitle: "추가")
        alert.addButton(withTitle: "취소")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://www.youtube.com/playlist?list=..."
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let urlString = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let playlistID = SubscribedPlaylist.playlistID(from: urlString), !playlistID.isEmpty else { return }
        guard !playlists.contains(where: { $0.id == playlistID }) else { return }
        var list = playlists
        list.append(SubscribedPlaylist(id: playlistID, title: "재생목록 (\(playlistID.prefix(6)))", url: urlString))
        SubscribedPlaylist.saveAll(list)
        playlists = list
    }

    private func deletePlaylist(_ playlist: SubscribedPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        SubscribedPlaylist.saveAll(playlists)
        let key = SubscribedPlaylist.storageKey(for: playlist.id)
        ChannelDownloadCache.clearNewVideoIds(channelId: key)
        ChannelDownloadCache.clearFetchDate(channelId: key)
    }
}

private struct ChannelRow: View {
    @Environment(\.imageCache) private var imageCache
    let channel: SubscribedChannel
    let isSelected: Bool
    var isDropTarget: Bool = false

    private var hasNewVideos: Bool {
        ChannelDownloadCache.hasNewVideos(channelId: channel.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            CachedAvatarView(channelId: channel.id, url: channel.avatarURL, size: 28)
                .clipShape(Circle())
                .overlay(
                    hasNewVideos
                        ? Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 10, y: -10)
                        : nil,
                    alignment: .topTrailing
                )
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(channel.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .primary)

                if let handle = channel.handle {
                    Text("@\(handle)")
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isDropTarget
                ? Color.accentColor.opacity(0.15)
                : (isSelected ? Color.accentColor : Color.clear)
        )
    }
}
