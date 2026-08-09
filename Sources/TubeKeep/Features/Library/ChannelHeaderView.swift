import SwiftUI
import ComposableArchitecture

struct ChannelHeaderView: View {
    let channelId: String
    let channelName: String
    let items: [LibraryItem]
    let store: StoreOf<AppReducer>

    @State private var channel: SubscribedChannel?
    @State private var avatar: NSImage?
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var channelItems: [LibraryItem] { items.filter { $0.channelId == channelId } }
    private var lastDownloadDate: Date? {
        channelItems.map(\.downloadDate).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
            avatarView
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(channelName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                    if let ch = channel {
                    HStack(spacing: 4) {
                        if let subs = ch.subscriberCount {
                            HStack(spacing: 2) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 9))
                                Text("구독자 \(formatSubs(subs))")
                            }
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "play.tv")
                                .font(.system(size: 9))
                            Text("영상 \(ch.videoCount)개")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                } else {
                    Text("채널 정보 없음")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 9))
                    Text("보관함: \(channelItems.count)개")

                    if let last = lastDownloadDate {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("마지막 \(last.formatted(.dateTime.year().month().day()))")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }

            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20)
            }

            channelButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.windowBackgroundColor))

            ChannelInsightCardView(channelId: channelId, channelName: channelName, items: items)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .id(channelId)
        .onAppear { loadChannelInfo() }
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Group {
            if let img = avatar {
                Image(nsImage: img)
                    .resizable()
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .overlay(
                        Text(String(channelName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    )
            }
        }
        .frame(width: 48, height: 48)
    }

    // MARK: - Buttons

    private var channelButtons: some View {
        HStack(spacing: 4) {
            Button {
                let url = "https://youtube.com/channel/\(channelId)"
                NSWorkspace.shared.open(URL(string: url)!)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "safari")
                        .font(.system(size: 10))
                    Text("YouTube에서 열기")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Button {
                store.send(.library(.openChannelDownload(channelId: channelId, channelName: channelName)))
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "tv")
                        .font(.system(size: 10))
                    Text("채널 다운로더")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Button {
                refreshChannelInfo()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("정보 갱신")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
        .fixedSize()
    }

    // MARK: - Data

    private func loadChannelInfo() {
        let chs = SubscribedChannel.loadAll()
        channel = chs.first(where: { $0.id == channelId })

        if let url = channel?.avatarURL, !url.isEmpty {
            if let cached = LibraryCacheService.shared.cachedAvatar(for: channelId) {
                avatar = cached
            } else {
                Task {
                    if let data = await LibraryCacheService.shared.loadAvatar(from: url, channelId: channelId),
                       let img = NSImage(data: data) {
                        await MainActor.run { avatar = img }
                    }
                }
            }
        }
    }

    private func refreshChannelInfo() {
        isRefreshing = true
        errorMessage = nil
        Task {
            do {
                let service = ChannelFetchService()
                let url: String
                if channelId.hasPrefix("UC") {
                    url = "https://www.youtube.com/channel/\(channelId)"
                } else if channelId.hasPrefix("@") {
                    url = "https://www.youtube.com/\(channelId)/videos"
                } else {
                    url = "https://www.youtube.com/@\(channelName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? channelName)/videos"
                }
                let fetched = try await service.fetchChannelInfo(from: url)

                var allChannels = SubscribedChannel.loadAll()
                if let idx = allChannels.firstIndex(where: { $0.id == channelId }) {
                    allChannels[idx] = fetched
                } else {
                    allChannels.append(fetched)
                }
                SubscribedChannel.saveAll(allChannels)

                await MainActor.run {
                    channel = fetched
                    errorMessage = nil
                    if let avatarURL = URL(string: fetched.avatarURL) {
                        Task {
                            if let data = try? await URLSession.shared.data(from: avatarURL).0,
                               let img = NSImage(data: data) {
                                LibraryCacheService.shared.cacheAvatar(for: channelId, data: data)
                                await MainActor.run { avatar = img }
                            }
                        }
                    }
                    isRefreshing = false
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: Constants.channelInfoDidUpdateNotification, object: nil, userInfo: ["channelId": channelId])
                }
            } catch {
                await MainActor.run {
                    errorMessage = "갱신 실패"
                    isRefreshing = false
                }
            }
        }
    }

    private func formatSubs(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f만", Double(count) / 10000)
        }
        return "\(count)"
    }
}
