import SwiftUI
import ComposableArchitecture

struct LibrarySidebarView: View {
    let store: StoreOf<AppReducer>
    @State private var channelNames: [(id: String, name: String, count: Int)] = []
    @State private var avatarImages: [String: NSImage] = [:]

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

            Divider()

            filterSection
                .padding(.vertical, 4)

            Divider()

            channelList
        }
        .background(Color(.windowBackgroundColor))
        .onChange(of: store.library.items) { newItems in
            updateChannelNames(newItems)
        }
        .onAppear {
            updateChannelNames(store.library.items)
        }
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
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel List

    private var channelList: some View {
        List {
            Section {} header: {
                Text("채널")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            ForEach(channelNames, id: \.id) { channel in
                channelRow(channel)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.visible)
    }

    private func channelRow(_ channel: (id: String, name: String, count: Int)) -> some View {
        Button {
            store.send(.library(.setFilterMode(.all)))
            store.send(.library(.setSelectedChannel(channel.id)))
        } label: {
            HStack(spacing: 8) {
                avatarView(for: channel.id)
                    .frame(width: 20, height: 20)

                Text(channel.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer()

                Text("\(channel.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("채널로 가기") {
                openChannelURL(channel.id)
            }
            Button("채널 다운로더 열기") {
                NotificationCenter.default.post(name: Constants.openChannelWindowNotification, object: nil)
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowSeparator(.hidden)
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
            if let cached = await service.cachedAvatar(for: channelId) {
                await MainActor.run { avatarImages[channelId] = cached }
                return
            }
            let channelItem = store.library.items.first(where: { $0.channelId == channelId })
            if let item = channelItem, !item.thumbnailURL.isEmpty,
               let url = URL(string: item.thumbnailURL) {
                do {
                    let req = URLRequest(url: url, timeoutInterval: 10)
                    let (data, _) = try await URLSession.shared.data(for: req)
                    await service.cacheAvatar(for: channelId, data: data)
                    if let img = NSImage(data: data) {
                        await MainActor.run { avatarImages[channelId] = img }
                        return
                    }
                } catch {}
            }
            await MainActor.run { avatarImages[channelId] = service.placeholderAvatar() }
        }
    }

    // MARK: - Helpers

    private func updateChannelNames(_ items: [LibraryItem]) {
        Task {
            let names = await LibraryCacheService.shared.channelNames(from: items)
            await MainActor.run {
                channelNames = names
            }
        }
    }
}
