import SwiftUI
import ComposableArchitecture

struct LibrarySidebarView: View {
    let store: StoreOf<AppReducer>
    @State private var channelNames: [(id: String, name: String, count: Int, avatarURL: String)] = []
    @State private var draggedChannelId: String?
    @State private var dropTargetIndex: Int?
    @AppStorage(Constants.channelOrderKey) private var channelOrderData: Data = Data()
    @State private var historyItems: [DownloadHistoryItem] = []
    @State private var pendingTrashChannel: (id: String, name: String)?
    @AppStorage(Constants.sidebarNavExpandedKey) private var isNavExpanded = false

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

            Group {
                if store.library.sidebarMode == .library {
                    VStack(spacing: 0) {
                        // 검색은 창 툴바(.searchable)로 이동 (T-1191)
                        filterSection
                            .padding(.vertical, 4)
                        Divider()
                        categorySection
                        Divider()
                        channelList
                    }
                } else if store.library.sidebarMode == .history {
                    historySidebar
                } else if store.library.sidebarMode == .profile {
                    VStack(spacing: 0) {
                        discoverSearchField
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        Divider()
                        VStack(spacing: 0) {
                            SectionHeader(title: "프로필")
                            profileCategoryRow
                                .padding(.bottom, 2)
                        }
                        .padding(.vertical, 4)
                    }
                } else if store.library.sidebarMode == .report {
                    Color.clear
                } else if store.library.sidebarMode == .clips {
                    Color.clear
                } else if store.library.sidebarMode == .diskCleanup {
                    Color.clear
                } else if store.library.sidebarMode == .trash {
                    Color.clear
                } else {
                    VStack(spacing: 0) {
                        discoverSearchField
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        Divider()
                        discoverCategorySection
                            .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

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
        .onChange(of: store.library.items) { _, newItems in
            updateChannelNames(newItems)
            updateLibraryCategoryRows(newItems)
        }
        .onChange(of: store.library.sidebarMode) { _, mode in
            if mode == .history { loadHistory() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.downloadHistoryDidChangeNotification)) { _ in
            if store.library.sidebarMode == .history { loadHistory() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.channelInfoDidUpdateNotification)) { note in
            if let channelId = note.userInfo?["channelId"] as? String {
                LibraryCacheService.shared.clearAvatarCache(for: channelId)
                // channelNames(from:)이 구독 아바타 URL을 병합하므로 목록 · 아바타 함께 갱신
                updateChannelNames(store.library.items)
            }
        }
        .onAppear {
            updateChannelNames(store.library.items)
            updateLibraryCategoryRows(store.library.items)
            store.send(.library(.calculateDiskUsage))
        }
        .alert("채널 영상 모두 삭제", isPresented: Binding(
            get: { pendingTrashChannel != nil },
            set: { if !$0 { pendingTrashChannel = nil } }
        )) {
            Button("취소", role: .cancel) {
                pendingTrashChannel = nil
            }
            Button("휴지통으로 이동", role: .destructive) {
                guard let ch = pendingTrashChannel else { return }
                store.send(.library(.trashChannelItems(channelId: ch.id, channelName: ch.name)))
                pendingTrashChannel = nil
                store.send(.library(.setSelectedChannel(nil)))
            }
        } message: {
            Text("'\(pendingTrashChannel?.name ?? "")' 채널의 다운로드 영상 \(pendingTrashChannel.flatMap { c in store.library.items.filter { $0.channelId == c.id || $0.channelName == c.name }.count } ?? 0)개가 휴지통으로 이동합니다. 복원 가능합니다.")
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: 2) {
            navRow(title: "보관함", icon: "square.grid.2x2", mode: .library)
            navRow(title: "트랜드", icon: "flame", mode: .discover)
            navRow(title: "다운로드 히스토리", icon: "clock.arrow.circlepath", mode: .history)

            if isNavExpanded {
                navRow(title: "클립", icon: "scissors", mode: .clips)
                navRow(title: "디스크 정리", icon: "externaldrive.badge.checkmark", mode: .diskCleanup)
                navRow(title: "내 프로필", icon: "person.text.rectangle", mode: .profile)
                navRow(title: "리포트", icon: "chart.bar.xaxis", mode: .report)
                navRow(title: "휴지통", icon: "trash", mode: .trash)
                toggleNavSheetButton(expanded: false)
            } else {
                toggleNavSheetButton(expanded: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: store.library.sidebarMode) { _, mode in
            if hiddenModes.contains(mode) && !isNavExpanded {
                isNavExpanded = true
            }
        }
        .onAppear {
            if hiddenModes.contains(store.library.sidebarMode) {
                isNavExpanded = true
            }
        }
    }

    private var hiddenModes: Set<LibrarySidebarMode> {
        [.clips, .diskCleanup, .profile, .report, .trash]
    }

    private func toggleNavSheetButton(expanded: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isNavExpanded = expanded
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: expanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(expanded ? "더 보기" : "접기")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func navRow(title: String, icon: String, mode: LibrarySidebarMode) -> some View {
        SidebarSelectableRow(
            title: title,
            isSelected: store.library.sidebarMode == mode,
            icon: icon,
            iconFrame: 16
        ) {
            store.send(.library(.setSidebarMode(mode)))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Discover Search

    private var discoverSearchField: some View {
        AppSearchField(
            placeholder: "검색...",
            text: Binding(
                get: { store.library.discoverSearchText },
                set: { store.send(.library(.setDiscoverSearchText($0))) }
            ),
            isSearching: store.library.discoverSearching,
            onSubmit: { store.send(.library(.discoverSearch)) }
        )
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
                        SectionHeader(title: "채널 필터")

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
        AppSearchField(placeholder: "검색...", text: Binding(
            get: { store.library.historySearchText },
            set: { store.send(.library(.setHistorySearchText($0))) }
        ))
    }

    private func historyChannelRow(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        SidebarSelectableRow(
            title: name,
            isSelected: isSelected,
            icon: "person",
            action: action
        )
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
            SectionHeader(title: "카테고리")

            ScrollView {
                LazyVStack(spacing: 2) {
                    profileCategoryRow
                        .padding(.bottom, 2)

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

    private var profileCategoryRow: some View {
        SidebarSelectableRow(
            title: "내 취향",
            isSelected: store.library.isShowingProfileRecommendations,
            icon: "heart",
            trailing: store.library.profileRecommendationsLoading ? {
                AnyView(ProgressView().scaleEffect(0.5).frame(width: 12, height: 12))
            } : nil
        ) {
            store.send(.library(.selectProfileRecommendations))
        }
    }

    private func categoryRow(_ category: TrendingCategory, count: Int, index: Int) -> some View {
        let isSelected = !store.library.isShowingProfileRecommendations && store.library.discoverCategory == category
        let isDropTarget = dropTargetCategoryIndex == index
        return HStack(spacing: 6) {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .help("드래그하여 순서 변경")

            Image(systemName: category.systemIcon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 20, height: 20)

            Text(category.rawValue)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? AppColors.selectedContentBackground : isDropTarget ? AppColors.hoverRow : Color.clear)
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

    // 보관함 검색 필드는 창 툴바(.searchable)로 이동됨 (T-1191)

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
                store.send(.library(.setSelectedCategory(nil)))
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
        SidebarSelectableRow(
            title: title,
            isSelected: isSelected,
            count: count,
            action: action
        )
    }

    // MARK: - Category Filter

    @State private var libraryCategoryRows: [(name: String, count: Int)] = []
    private let categoryRowHeight: CGFloat = 26
    private let categorySectionMaxRows = 4
    private var categorySectionHeight: CGFloat {
        categoryRowHeight * CGFloat(categorySectionMaxRows)
            + 20   // LazyVStack spacing 2 × 10개 간격
            + 8    // LazyVStack padding .vertical 4×2
    }

    private var categorySection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "카테고리")
                .padding(.top, 4)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(libraryCategoryRows, id: \.name) { row in
                        categoryFilterRow(row)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: categorySectionHeight)
        }
    }

    private func categoryFilterRow(_ row: (name: String, count: Int)) -> some View {
        SidebarSelectableRow(
            title: row.name,
            isSelected: store.library.selectedCategory == row.name,
            icon: categorySystemIcon(row.name),
            count: row.count
        ) {
            store.send(.library(.setSelectedCategory(store.library.selectedCategory == row.name ? nil : row.name)))
        }
        .frame(height: categoryRowHeight)
    }

    private func categorySystemIcon(_ name: String) -> String {
        switch name {
        case "기술/IT": return "desktopcomputer"
        case "음악": return "music.note"
        case "게임": return "gamecontroller.fill"
        case "뉴스/시사": return "newspaper.fill"
        case "스포츠": return "sportscourt.fill"
        case "엔터테인먼트": return "tv.fill"
        case "교육/강의": return "graduationcap.fill"
        case "요리/음식": return "fork.knife"
        case "여행/일상": return "airplane"
        case "과학": return "atom"
        default: return "tag.fill"
        }
    }

    private func updateLibraryCategoryRows(_ items: [LibraryItem]) {
        var counts: [String: Int] = [:]
        for item in items {
            for tag in item.tags {
                counts[tag, default: 0] += 1
            }
        }
        libraryCategoryRows = counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
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
        SectionHeader(title: "채널")
    }

    private func channelRow(_ channel: (id: String, name: String, count: Int, avatarURL: String), index: Int) -> some View {
        let isSelected = store.library.filterMode == .all && store.library.selectedChannel == channel.id
        let isDropTarget = dropTargetIndex == index
        return HStack(spacing: 6) {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .help("드래그하여 순서 변경")

            CachedAvatarView(channelId: channel.id, url: channel.avatarURL, size: 20)

            Text(channel.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(channel.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
            .background(isSelected ? AppColors.selectedContentBackground : isDropTarget ? AppColors.hoverRow : Color.clear)
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
            Divider()
            Button("채널 영상 모두 삭제", role: .destructive) {
                pendingTrashChannel = (channel.id, channel.name)
            }
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

// MARK: - Drop Delegate

private struct ChannelDropDelegate: DropDelegate {
    let channel: (id: String, name: String, count: Int, avatarURL: String)
    let currentIndex: Int
    @Binding var channelNames: [(id: String, name: String, count: Int, avatarURL: String)]
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
