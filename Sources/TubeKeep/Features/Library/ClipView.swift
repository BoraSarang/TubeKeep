import SwiftUI
import ComposableArchitecture

struct ClipView: View {
    let store: StoreOf<AppReducer>
    @State private var thumbnailImages: [String: NSImage] = [:]

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 300), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            if store.clip.clips.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.clip.clips) { clip in
                            clipCell(clip)
                                .onAppear { loadThumbnail(for: clip) }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            store.send(.clip(.load))
        }
    }

    private var header: some View {
        HStack {
            Text("\(store.clip.clips.count)개 클립")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if store.clip.savingClip {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini).scaleEffect(0.7)
                    Text("저장 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "scissors")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("클립이 없습니다")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("플레이어에서 A·B 반복 구간을 설정한 뒤\n디스켓(저장) 버튼을 누르면 여기에 저장됩니다")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func clipCell(_ clip: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnailView(for: clip)
                .overlay(alignment: .bottomLeading) {
                    Text(formatDuration(clip.duration))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }

            Text(clip.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)

            HStack(spacing: 3) {
                if let channel = clip.channelName, !channel.isEmpty {
                    Image(systemName: "person.crop.square")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(channel)
                        .lineLimit(1)
                } else {
                    Text(clip.videoId)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            Text("\(timeString(clip.start)) ~ \(timeString(clip.end)) · \(clip.createdAt.formatted(.dateTime.month().day().hour().minute()))")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .onTapGesture {
            openClip(clip)
        }
        .contextMenu {
            Button("재생") { openClip(clip) }
            Button("Finder에서 보기") { revealInFinder(clip) }
            Divider()
            Button("삭제", role: .destructive) {
                store.send(.clip(.deleteClip(clip)))
            }
        }
        .help(clip.filePath)
    }

    private func openClip(_ clip: ClipItem) {
        let playerItem = PlayerItem(
            fileURL: URL(fileURLWithPath: clip.filePath),
            title: "클립 · \(clip.title)",
            duration: TimeInterval(clip.duration)
        )
        NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem)
    }

    private func thumbnailView(for clip: ClipItem) -> some View {
        Color.clear
            .overlay {
                if let img = thumbnailImages[clip.id] {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            Image(systemName: "film.stack")
                                .font(.system(size: 26))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .clipped()
    }

    private func loadThumbnail(for clip: ClipItem) {
        guard thumbnailImages[clip.id] == nil,
              let path = clip.thumbnailPath,
              FileManager.default.fileExists(atPath: path),
              let img = NSImage(contentsOfFile: path) else { return }
        thumbnailImages[clip.id] = img
    }

    private func revealInFinder(_ clip: ClipItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: clip.filePath)])
    }

    private func timeString(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return "\(seconds)초"
    }
}
