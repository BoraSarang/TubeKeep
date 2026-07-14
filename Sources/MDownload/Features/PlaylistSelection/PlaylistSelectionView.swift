import SwiftUI
import ComposableArchitecture

struct PlaylistSelectionView: View {
    @ObservedObject var store: StoreOf<PlaylistSelectionReducer>

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if store.isFetching {
                Spacer()
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("재생목록을 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if let error = store.errorMessage {
                Spacer()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Spacer()
            } else {
                controlsView
                listView
                footerView
            }
        }
        .frame(width: 500, height: 400)
    }

    private var headerView: some View {
        HStack {
            Text(store.playlistTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text("(\(store.selectedIds.count)/\(store.videos.count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("취소") {
                store.send(.cancel)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var controlsView: some View {
        HStack(spacing: 8) {
            if store.isAllSelected {
                Button("전체 해제") {
                    store.send(.deselectAll)
                }
                .buttonStyle(.plain)
                .font(.caption)
            } else {
                Button("전체 선택") {
                    store.send(.selectAll)
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            Spacer()

            Picker(
                "정렬",
                selection: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.changeSortOrder($0)) }
                )
            ) {
                ForEach(PlaylistSelectionReducer.State.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
            .frame(width: 180)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var listView: some View {
        List {
            ForEach(store.sortedVideos) { video in
                PlaylistRow(
                    video: video,
                    isSelected: store.selectedIds.contains(video.id)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    store.send(.toggleVideo(video.id))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.plain)
    }

    private var footerView: some View {
        HStack {
            Text("선택한 \(store.selectedIds.count)개를 다운로드합니다")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("선택 항목 다운로드") {
                store.send(.confirmSelection)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.selectedIds.isEmpty)
        }
        .padding(12)
    }
}

struct PlaylistRow: View {
    let video: VideoInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                .font(.system(size: 16))

            AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 80, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.system(size: 12))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(video.channel)
                    Text(video.formattedDuration)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(video.formattedDate)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
