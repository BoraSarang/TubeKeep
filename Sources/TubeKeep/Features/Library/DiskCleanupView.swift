import SwiftUI
import ComposableArchitecture

enum DiskCleanupSort: String, CaseIterable, Identifiable {
    case sizeDesc = "용량 큰 순"
    case dateDesc = "최근 다운로드 순"
    case channel = "채널순"

    var id: String { rawValue }
}

enum DiskCleanupFilter: String, CaseIterable, Identifiable {
    case all = "모두"
    case over500MB = "500MB 이상"
    case over1GB = "1GB 이상"
    case over5GB = "5GB 이상"

    var id: String { rawValue }

    var threshold: Int64? {
        switch self {
        case .all: return nil
        case .over500MB: return 500_000_000
        case .over1GB: return 1_000_000_000
        case .over5GB: return 5_000_000_000
        }
    }
}

struct DiskCleanupView: View {
    let store: StoreOf<AppReducer>
    @State private var sort: DiskCleanupSort = .sizeDesc
    @State private var filter: DiskCleanupFilter = .all
    @State private var sizes: [String: Int64] = [:]
    @State private var thumbnails: [String: NSImage] = [:]
    @State private var selectedIDs: Set<String> = []

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 300), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if !selectedIDs.isEmpty {
                selectionBar
                Divider()
            }
            if filteredItems.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredItems) { item in
                            cell(for: item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            if sizes.isEmpty {
                for item in store.library.items {
                    sizes[item.id] = Self.fileSize(of: item.filePath)
                }
            }
        }
    }

    private var totalBytes: Int64 {
        sizes.values.reduce(0, +)
    }

    private var filteredItems: [LibraryItem] {
        var result = store.library.items.filter { item in
            guard let threshold = filter.threshold else { return true }
            return (sizes[item.id] ?? 0) >= threshold
        }
        switch sort {
        case .sizeDesc:
            result.sort { (sizes[$0.id] ?? 0) > (sizes[$1.id] ?? 0) }
        case .dateDesc:
            result.sort { $0.downloadDate > $1.downloadDate }
        case .channel:
            result.sort { $0.channelName.localizedCaseInsensitiveCompare($1.channelName) == .orderedAscending }
        }
        return result
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("디스크 정리")
                    .font(.system(size: 12, weight: .semibold))
                Text("총 \(formatBytes(totalBytes)) 사용 중")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $filter) {
                ForEach(DiskCleanupFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 110)
            Picker("", selection: $sort) {
                ForEach(DiskCleanupSort.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 130)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var selectionBar: some View {
        SelectionBar(
            count: selectedIDs.count,
            isAllSelected: !selectedIDs.isEmpty && selectedIDs.count == filteredItems.count,
            onToggleSelectAll: {
                if selectedIDs.count == filteredItems.count {
                    selectedIDs = []
                } else {
                    selectedIDs = Set(filteredItems.map(\.id))
                }
            },
            onClearSelection: { selectedIDs = [] },
            onReveal: { store.send(.library(.revealSelectedInFinder)) },
            onDelete: {
                store.send(.library(.removeItems(Array(selectedIDs))))
                selectedIDs = []
            },
            showsDeselect: false
        )
    }

    private var emptyState: some View {
        EmptyStateView(icon: "externaldrive.badge.checkmark", title: "조건에 맞는 영상이 없습니다")
    }

    // MARK: - Cell

    private func cell(for item: LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .overlay {
                    if let img = thumbnails[item.id] {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(Image(systemName: "film").foregroundStyle(.secondary))
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selectedIDs.contains(item.id) ? Color.accentColor : Color(.separatorColor), lineWidth: selectedIDs.contains(item.id) ? 2 : 0.5)
                )
                .overlay(alignment: .bottomLeading) {
                    Text(formatBytes(sizes[item.id] ?? 0))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(5)
                }

            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)

            HStack(spacing: 3) {
                Image(systemName: "person.crop.square")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(item.channelName)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            Text("다운로드 \(item.downloadDate.formatted(.dateTime.month().day().year()))")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .onTapGesture {
            if selectedIDs.contains(item.id) {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
        }
        .contextMenu {
            Button("Finder에서 보기") { reveal(item) }
            Divider()
            Button("삭제", role: .destructive) {
                store.send(.library(.removeItems([item.id])))
            }
        }
        .onAppear {
            loadThumbnail(for: item)
        }
    }

    // MARK: - Helpers

    private func loadThumbnail(for item: LibraryItem) {
        guard thumbnails[item.id] == nil else { return }
        let service = LibraryCacheService.shared
        Task {
            if let cached = service.cachedThumbnail(for: item.id) {
                await MainActor.run { thumbnails[item.id] = cached }
                return
            }
            if let data = await service.loadThumbnail(from: item.thumbnailURL, videoId: item.id),
               let img = NSImage(data: data) {
                await MainActor.run { thumbnails[item.id] = img }
            }
        }
    }

    private func reveal(_ item: LibraryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.filePath)])
    }

    nonisolated private static func fileSize(of path: String) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return 0 }
        return (attrs[.size] as? Int64) ?? 0
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
