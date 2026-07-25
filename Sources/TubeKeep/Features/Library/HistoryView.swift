import SwiftUI
import ComposableArchitecture

struct HistoryView: View {
    let store: StoreOf<AppReducer>
    @State private var items: [DownloadHistoryItem] = []
    @State private var selectedFilter: FilterOption = .all

    enum FilterOption: String, CaseIterable {
        case all = "전체"
        case today = "오늘"
        case yesterday = "어제"
        case thisWeek = "이번주"
        case thisMonth = "이번달"

        var calendarComponent: Calendar.Component? {
            switch self {
            case .all: return nil
            case .today: return .day
            case .yesterday: return .day
            case .thisWeek: return .weekOfYear
            case .thisMonth: return .month
            }
        }

        var componentValue: Int {
            switch self {
            case .today: return 0
            case .yesterday: return -1
            case .thisWeek: return 0
            case .thisMonth: return 0
            case .all: return 0
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            if filteredItems.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HistoryRow(item: item)
                            .contextMenu {
                                if item.status == "completed" {
                                    Button("Finder에서 보기") {
                                        guard let path = item.filePath,
                                              FileManager.default.fileExists(atPath: path)
                                        else { return }
                                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                    }
                                    .disabled(item.filePath == nil || !(item.filePath.map { FileManager.default.fileExists(atPath: $0) } ?? false))

                                    Button("다시 다운로드") {
                                        retryDownload(url: item.url)
                                    }
                                } else {
                                    Button("다시 시작") {
                                        retryDownload(url: item.url)
                                    }
                                }
                                Divider()
                                Button("삭제", role: .destructive) {
                                    DatabaseManager.shared.deleteDownloadHistory(id: item.id)
                                    loadItems()
                                }
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = filteredItems[index]
                            DatabaseManager.shared.deleteDownloadHistory(id: item.id)
                        }
                        loadItems()
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear(perform: loadItems)
        .onReceive(NotificationCenter.default.publisher(for: Constants.downloadHistoryDidChangeNotification)) { _ in
            loadItems()
        }
        .onChange(of: store.library.sidebarMode) { _, mode in
            if mode == .history { loadItems() }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Text("총 \(items.count)개 항목")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Picker("", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            if !items.isEmpty {
                Button(role: .destructive) {
                    let alert = NSAlert()
                    alert.messageText = "삭제하시겠습니까?"
                    if let channel = store.library.historyFilterChannel {
                        alert.informativeText = "선택한 채널(\(channel))의 히스토리를 모두 삭제합니다."
                    } else {
                        alert.informativeText = "모든 다운로드 히스토리를 삭제합니다."
                    }
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "삭제")
                    alert.addButton(withTitle: "취소")
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let channel = store.library.historyFilterChannel {
                            DatabaseManager.shared.deleteDownloadHistory(channel: channel)
                        } else {
                            DatabaseManager.shared.deleteAllDownloadHistory()
                        }
                        loadItems()
                        NotificationCenter.default.post(name: Constants.downloadHistoryDidChangeNotification, object: nil)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(store.library.historyFilterChannel.map { "\($0) 히스토리 삭제" } ?? "전체 삭제")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("다운로드 히스토리가 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredItems: [DownloadHistoryItem] {
        var result = items

        if let filterChannel = store.library.historyFilterChannel {
            result = result.filter { $0.channelName == filterChannel }
        }

        if !store.library.historySearchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(store.library.historySearchText) ||
                ($0.channelName ?? "").localizedCaseInsensitiveContains(store.library.historySearchText)
            }
        }

        switch selectedFilter {
        case .today:
            result = result.filter { Calendar.current.isDateInToday($0.downloadedAt) }
        case .yesterday:
            result = result.filter { Calendar.current.isDateInYesterday($0.downloadedAt) }
        case .thisWeek:
            result = result.filter { Calendar.current.isDate($0.downloadedAt, equalTo: Date(), toGranularity: .weekOfYear) }
        case .thisMonth:
            result = result.filter { Calendar.current.isDate($0.downloadedAt, equalTo: Date(), toGranularity: .month) }
        case .all:
            break
        }

        return result
    }

    private func loadItems() {
        items = DatabaseManager.shared.loadDownloadHistory()
        #if DEBUG
        let comp = items.filter { $0.status == "completed" }.count
        let fail = items.filter { $0.status == "failed" }.count
        Task { @MainActor in DebugLogManager.shared?.append("[HistoryView] 로드: \(items.count)개 (완료:\(comp) 실패:\(fail))") }
        #endif
    }

    private func retryDownload(url: String) {
        if store.settings.smartMode && store.settings.activePresetId != nil {
            store.send(.home(.autoFetchInfo(url)))
        } else {
            NotificationCenter.default.post(
                name: Constants.openDownloaderWindowNotification,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }
}

struct HistoryRow: View {
    let item: DownloadHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let channel = item.channelName {
                        Text(channel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    if let label = item.formatLabel {
                        Text(label)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    if let res = item.resolution, res > 0 {
                        Text("\(res)p")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(item.formattedDate)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(item.statusBadgeText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.statusBadgeColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
