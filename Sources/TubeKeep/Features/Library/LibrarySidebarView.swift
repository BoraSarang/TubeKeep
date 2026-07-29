import SwiftUI
import ComposableArchitecture

struct LibrarySidebarView: View {
    let store: StoreOf<AppReducer>
    @State private var channelNames: [(id: String, name: String, count: Int)] = []
    @State private var avatarImages: [String: NSImage] = [:]
    @State private var draggedChannelId: String?
    @State private var dropTargetIndex: Int?
    @AppStorage(Constants.channelOrderKey) private var channelOrderData: Data = Data()
    @State private var historyItems: [DownloadHistoryItem] = []

    private var channelOrder: [String] {
        get { (try? JSONDecoder().decode([String].self, from: channelOrderData)) ?? [] }
        set { channelOrderData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private func saveChannelOrder() {
        let order = channelNames.map(\.id)
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: Constants.channelOrderKey)
        }
    }

    private func moveChannel(from source: Int, to destination: Int) {
        guard source != destination else { return }
        channelNames.move(fromOffsets: IndexSet(integer: source), toOffset: destination > source ? destination + 1 : destination)
        saveChannelOrder()
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationSection
                .padding(.vertical, 4)

            Divider()

            if store.library.sidebarMode == .library {
                searchField
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                Divider()

                filterSection
                    .padding(.vertical, 4)

                Divider()

                channelList
            } else if store.library.sidebarMode == .history {
                historySidebar
            } else {
                discoverSearchField
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                Divider()

                discoverCategorySection
                    .padding(.vertical, 4)

                Divider()
            }

            HStack(spacing: 0) {
                Button {
                    let dir = store.settings.storageDirectory
                    let url = URL(fileURLWithPath: dir)
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                        Text("Finder에서 보기")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    store.send(.library(.calculateDiskUsage))
                } label: {
                    HStack(spacing: 2) {
                        Text(formatBytes(store.library.diskUsageBytes))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.trailing, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("용량 새로고침")
            }
        }
        .background(Color(.windowBackgroundColor))
        .onChange(of: store.library.items) { _, newItems in
            updateChannelNames(newItems)
        }
        .onChange(of: store.library.sidebarMode) { _, mode in
            if mode == .history { loadHistory() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.downloadHistoryDidChangeNotification)) { _ in
            if store.library.sidebarMode == .history { loadHistory() }
        }
        .onAppear {
            updateChannelNames(store.library.items)
            store.send(.library(.calculateDiskUsage))
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: 2) {
            navRow(title: "보관함", icon: "square.grid.2x2", mode: .library)
            navRow(title: "트랜드", icon: "flame", mode: .discover)
            navRow(title: "다운로드 히스토리", icon: "clock.arrow.circlepath", mode: .history)
        }
    }

    private func navRow(title: String, icon: String, mode: LibrarySidebarMode) -> some View {
        let isSelected = store.library.sidebarMode == mode
        return Button {
            store.send(.library(.setSidebarMode(mode)))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - Discover Search

    private var discoverSearchField: some View {
        HStack(spacing: 4) {
            Group {
                if store.library.discoverSearching {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 14, height: 14)

            TextField("검색...", text: Binding(
                get: { store.library.discoverSearchText },
                set: { store.send(.library(.setDiscoverSearchText($0))) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .onSubmit {
                store.send(.library(.discoverSearch))
            }

            if !store.library.discoverSearchText.isEmpty {
                Button {
                    store.send(.library(.setDiscoverSearchText("")))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Discover Categories

    @State private var categoryRows: [(category: TrendingCategory, count: Int)] = []
    @State private var draggedCategoryName: String?
    @State private var dropTargetCategoryIndex: Int?
    @AppStorage("discoverCategoryOrder") private var categoryOrderData: Data = Data()

    private var categoryOrder: [String] {
        get { (try? JSONDecoder().decode([String].self, from: categoryOrderData)) ?? [] }
        set { categoryOrderData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    private func saveCategoryOrder() {
        let order = categoryRows.map(\.category.rawValue)
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: "discoverCategoryOrder")
        }
    }

    private func moveCategory(from source: Int, to destination: Int) {
        guard source != destination else { return }
        categoryRows.move(fromOffsets: IndexSet(integer: source), toOffset: destination > source ? destination + 1 : destination)
        saveCategoryOrder()
    }

    private func updateCategoryRows() {
        let order = categoryOrder
        var sorted: [(TrendingCategory, Int)] = []
        let all = TrendingCategory.allCases
        for name in order {
            if let cat = all.first(where: { $0.rawValue == name }) {
                sorted.append((cat, store.library.discoverVideos[cat]?.count ?? 0))
            }
        }
        for cat in all {
            if !sorted.contains(where: { $0.0 == cat }) {
                sorted.append((cat, store.library.discoverVideos[cat]?.count ?? 0))
            }
        }
        categoryRows = sorted
    }

    // MARK: - History

    private var historySidebar: some View {
        ScrollView {
            VStack(spacing: 0) {
                historySearchField
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                if historyChannels.count > 1 {
                    Divider()
                        .padding(.leading, 12)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("채널 필터")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                        historyChannelRow(name: "전체", isSelected: store.library.historyFilterChannel == nil) {
                            store.send(.library(.setHistoryFilterChannel(nil)))
                        }

                        ForEach(historyChannels, id: \.self) { channel in
                            historyChannelRow(name: channel, isSelected: store.library.historyFilterChannel == channel) {
                                store.send(.library(.setHistoryFilterChannel(
                                    store.library.historyFilterChannel == channel ? nil : channel
                                )))
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private var historyStats: some View {
        VStack(spacing: 4) {
            HStack {
                Text("히스토리")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(historyItems.count)개")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historySearchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("검색...", text: Binding(
                get: { store.library.historySearchText },
                set: { store.send(.library(.setHistorySearchText($0))) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))

            if !store.library.historySearchText.isEmpty {
                Button {
                    store.send(.library(.setHistorySearchText("")))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func historyChannelRow(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20, height: 20)

            Text(name)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private var historyChannels: [String] {
        Array(Set(historyItems.compactMap { $0.channelName })).sorted()
    }

    private func loadHistory() {
        historyItems = DatabaseManager.shared.loadDownloadHistory()
        #if DEBUG
        let comp = historyItems.filter { $0.status == "completed" }.count
        let fail = historyItems.filter { $0.status == "failed" }.count
        Task { @MainActor in DebugLogManager.shared?.append("[History] 로드: \(historyItems.count)개 (완료:\(comp) 실패:\(fail))") }
        #endif
    }

    private var discoverCategorySection: some View {
        VStack(spacing: 0) {
            Text("카테고리")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(categoryRows.enumerated()), id: \.element.category) { index, row in
                        categoryRow(row.category, count: row.count, index: index)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: store.library.discoverVideos) { _, _ in
            updateCategoryRows()
        }
        .onAppear {
            updateCategoryRows()
        }
    }

    private func categoryRow(_ category: TrendingCategory, count: Int, index: Int) -> some View {
        let isSelected = store.library.discoverCategory == category
        let isDropTarget = dropTargetCategoryIndex == index
        return HStack(spacing: 6) {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .help("드래그하여 순서 변경")

            Image(systemName: category.systemIcon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20, height: 20)

            Text(category.rawValue)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary)

            Spacer()

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : isDropTarget ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.library(.selectDiscoverCategory(category)))
        }
        .contextMenu {
            Button("위로 이동") {
                guard index > 0 else { return }
                moveCategory(from: index, to: index - 1)
            }
            .disabled(index == 0)
            Button("아래로 이동") {
                guard index < categoryRows.count - 1 else { return }
                moveCategory(from: index, to: index + 1)
            }
            .disabled(index == categoryRows.count - 1)
        }
        .onDrag {
            draggedCategoryName = category.rawValue
            return NSItemProvider(object: category.rawValue as NSString)
        }
        .onDrop(of: [.text], delegate: CategoryDropDelegate(
            category: category,
            currentIndex: index,
            categoryRows: $categoryRows,
            draggedCategoryName: $draggedCategoryName,
            dropTargetIndex: $dropTargetCategoryIndex,
            onMove: moveCategory
        ))
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("검색...", text: Binding(
                get: { store.library.searchText },
                set: { store.send(.library(.setSearchText($0))) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))

            if !store.library.searchText.isEmpty {
                Button {
                    store.send(.library(.setSearchText("")))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Filter

    private var filterSection: some View {
        VStack(spacing: 2) {
            filterRow(
                title: "전체",
                count: store.library.items.count,
                isSelected: store.library.filterMode == .all && store.library.selectedChannel == nil
            ) {
                store.send(.library(.setFilterMode(.all)))
                store.send(.library(.setSelectedChannel(nil)))
            }

            filterRow(
                title: "최근",
                count: recentCount,
                isSelected: store.library.filterMode == .recent
            ) {
                store.send(.library(.setFilterMode(.recent)))
                store.send(.library(.setSelectedChannel(nil)))
            }
        }
    }

    private var recentCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return store.library.items.filter { $0.downloadDate >= cutoff }.count
    }

    private func filterRow(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel List

    private var channelList: some View {
        VStack(spacing: 0) {
            channelHeader
                .padding(.top, 4)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(channelNames.enumerated()), id: \.element.id) { index, channel in
                        channelRow(channel, index: index)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            Button {
                NotificationCenter.default.post(name: Constants.openChannelWindowNotification, object: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                    Text("채널 추가")
                        .font(.system(size: 12))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var channelHeader: some View {
        HStack {
            Text("채널")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func channelRow(_ channel: (id: String, name: String, count: Int), index: Int) -> some View {
        let isSelected = store.library.filterMode == .all && store.library.selectedChannel == channel.id
        let isDropTarget = dropTargetIndex == index
        return HStack(spacing: 6) {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .help("드래그하여 순서 변경")

            avatarView(for: channel.id)
                .frame(width: 20, height: 20)

            Text(channel.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary)

            Spacer()

            Text("\(channel.count)")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : isDropTarget ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.library(.setFilterMode(.all)))
            store.send(.library(.setSelectedChannel(channel.id)))
        }
        .contextMenu {
            Button("채널로 가기") {
                openChannelURL(channel.id)
            }
            Button("채널 다운로더 실행") {
                NotificationCenter.default.post(
                    name: Constants.openChannelWithIdNotification,
                    object: nil,
                    userInfo: ["channelId": channel.id, "channelName": channel.name]
                )
            }
            Divider()
            Button("위로 이동") {
                guard index > 0 else { return }
                moveChannel(from: index, to: index - 1)
            }
            .disabled(index == 0)
            Button("아래로 이동") {
                guard index < channelNames.count - 1 else { return }
                moveChannel(from: index, to: index + 1)
            }
            .disabled(index == channelNames.count - 1)
        }
        .onDrag {
            draggedChannelId = channel.id
            return NSItemProvider(object: channel.id as NSString)
        }
        .onDrop(of: [.text], delegate: ChannelDropDelegate(
            channel: channel,
            currentIndex: index,
            channelNames: $channelNames,
            draggedChannelId: $draggedChannelId,
            dropTargetIndex: $dropTargetIndex,
            onMove: moveChannel
        ))
    }

    private func openChannelURL(_ channelId: String) {
        let urlString = "https://youtube.com/channel/\(channelId)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Avatar

    private func avatarView(for channelId: String) -> some View {
        Group {
            if let img = avatarImages[channelId] {
                Image(nsImage: img)
                    .resizable()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
                    .onAppear {
                        loadAvatar(channelId: channelId)
                    }
            }
        }
        .frame(width: 20, height: 20)
    }

    private func loadAvatar(channelId: String) {
        guard avatarImages[channelId] == nil else { return }
        let service = LibraryCacheService.shared
        Task {
            if let cached = service.cachedAvatar(for: channelId) {
                await MainActor.run { avatarImages[channelId] = cached }
                return
            }
            await MainActor.run { avatarImages[channelId] = service.placeholderAvatar() }
        }
    }

// MARK: - Drop Delegate

private struct ChannelDropDelegate: DropDelegate {
    let channel: (id: String, name: String, count: Int)
    let currentIndex: Int
    @Binding var channelNames: [(id: String, name: String, count: Int)]
    @Binding var draggedChannelId: String?
    @Binding var dropTargetIndex: Int?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        dropTargetIndex = currentIndex
    }

    func dropExited(info: DropInfo) {
        if dropTargetIndex == currentIndex {
            dropTargetIndex = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { dropTargetIndex = nil }
        guard let draggedId = draggedChannelId,
              let fromIdx = channelNames.firstIndex(where: { $0.id == draggedId }),
              fromIdx != currentIndex
        else {
            draggedChannelId = nil
            return false
        }
        onMove(fromIdx, currentIndex)
        draggedChannelId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct CategoryDropDelegate: DropDelegate {
    let category: TrendingCategory
    let currentIndex: Int
    @Binding var categoryRows: [(category: TrendingCategory, count: Int)]
    @Binding var draggedCategoryName: String?
    @Binding var dropTargetIndex: Int?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        dropTargetIndex = currentIndex
    }

    func dropExited(info: DropInfo) {
        if dropTargetIndex == currentIndex {
            dropTargetIndex = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { dropTargetIndex = nil }
        guard let draggedName = draggedCategoryName,
              let fromIdx = categoryRows.firstIndex(where: { $0.category.rawValue == draggedName }),
              fromIdx != currentIndex
        else {
            draggedCategoryName = nil
            return false
        }
        onMove(fromIdx, currentIndex)
        draggedCategoryName = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

    // MARK: - Helpers

    private func updateChannelNames(_ items: [LibraryItem]) {
        Task {
            let names = LibraryCacheService.shared.channelNames(from: items)
            await MainActor.run {
                let order = channelOrder
                channelNames = names.sorted { a, b in
                    guard let ai = order.firstIndex(of: a.id),
                          let bi = order.firstIndex(of: b.id) else {
                        return order.contains(a.id) && !order.contains(b.id)
                    }
                    return ai < bi
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
