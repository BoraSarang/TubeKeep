import SwiftUI
import AppKit
import ComposableArchitecture

struct TrashView: View {
    let store: StoreOf<AppReducer>
    @State private var thumbnailImages: [String: NSImage] = [:]
    @State private var showEmptyConfirm = false
    @State private var pendingPermanent: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f
    }()

    var body: some View {
        let items = store.library.trashItems
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("휴지통")
                    .font(.headline)
                Spacer()
                Text("30일이 지난 항목은 자동으로 삭제됩니다")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Button("전체 비우기") { showEmptyConfirm = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(items.isEmpty)
            }
            .padding(12)

            Divider()

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("휴지통이 비어 있습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            row(item)
                            Divider()
                        }
                    }
                }
            }
        }
        .alert("휴지통 비우기", isPresented: $showEmptyConfirm) {
            Button("취소", role: .cancel) {}
            Button("전체 삭제", role: .destructive) {
                store.send(.library(.emptyTrash))
            }
        } message: {
            Text("휴지통의 모든 항목이 영구 삭제됩니다. 되돌릴 수 없습니다.")
        }
        .alert("영구 삭제", isPresented: Binding(
            get: { pendingPermanent != nil },
            set: { if !$0 { pendingPermanent = nil } }
        )) {
            Button("취소", role: .cancel) { pendingPermanent = nil }
            Button("영구 삭제", role: .destructive) {
                if let id = pendingPermanent {
                    store.send(.library(.deletePermanently(id)))
                }
                pendingPermanent = nil
            }
        } message: {
            Text("이 영상을 완전히 삭제합니다. 복원할 수 없습니다.")
        }
    }

    private func row(_ item: LibraryItem) -> some View {
        HStack(spacing: 10) {
            thumbnailView(item)
                .frame(width: 88, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 4) {
                    Text(item.channelName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if let trashedAt = item.trashedAt {
                        Text("삭제: \(dateFormatter.string(from: trashedAt))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Button {
                store.send(.library(.restoreItem(item.id)))
            } label: {
                Label("복원", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                pendingPermanent = item.id
            } label: {
                Label("영구 삭제", systemImage: "trash.slash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contextMenu {
            Button("복원") { store.send(.library(.restoreItem(item.id))) }
            Divider()
            Button("영구 삭제", role: .destructive) { pendingPermanent = item.id }
        }
        .onAppear { loadThumbnail(for: item) }
    }

    private func thumbnailView(_ item: LibraryItem) -> some View {
        Group {
            if let img = thumbnailImages[item.id] {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AppColors.textBackground)
                    .overlay(
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

    private func loadThumbnail(for item: LibraryItem) {
        guard thumbnailImages[item.id] == nil else { return }
        let service = LibraryCacheService.shared
        guard let img = service.cachedThumbnail(for: item.id) else { return }
        thumbnailImages[item.id] = img
    }
}