import SwiftUI
import UniformTypeIdentifiers

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
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

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                        ChannelRow(
                            channel: channel,
                            isSelected: selectedChannel?.id == channel.id,
                            isDropTarget: dropTargetIndex == index
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(channel) }
                        .contextMenu {
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
            }
        }
    }
}

private struct ChannelRow: View {
    let channel: SubscribedChannel
    let isSelected: Bool
    var isDropTarget: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            if !channel.avatarURL.isEmpty, let url = URL(string: channel.avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.secondary)
            }

            Text(channel.name)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary)

            if let subs = channel.subscriberCount {
                Text(formatSubscriberCount(subs))
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            isDropTarget
                ? Color.accentColor.opacity(0.15)
                : (isSelected ? Color.accentColor : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private func formatSubscriberCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let num = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "구독자 \(num)명"
    }
}
