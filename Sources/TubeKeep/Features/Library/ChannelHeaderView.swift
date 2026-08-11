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
        .onAppear {
            errorMessage = nil
            loadChannelInfo()
        }
        .onChange(of: channelId) { _, _ in
            errorMessage = nil
            avatar = nil
            isRefreshing = false
            loadChannelInfo()
        }
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
        avatar = nil
        let chs = SubscribedChannel.loadAll()
        channel = chs.first(where: { $0.id == channelId })

        // 캐시는 channelId 키로 공유 → url과 무관하게 우선 조회
        if let cached = LibraryCacheService.shared.cachedAvatar(for: channelId) {
            avatar = cached
            DebugLogManager.shared?.append("[Channel] 📦 헤더 아바타 캐시 사용: \(channelId)")
            return
        }

        guard let url = channel?.avatarURL, !url.isEmpty else { return }
        DebugLogManager.shared?.append("[Channel] 🌐 헤더 아바타 다운로드 시작: \(channelId)")
        Task {
            if let data = await LibraryCacheService.shared.loadAvatar(from: url, channelId: channelId),
               let img = NSImage(data: data) {
                await MainActor.run { avatar = img }
                DebugLogManager.shared?.append("[Channel] 🖼️ 헤더 아바타 다운로드 완료: \(channelId)")
            }
        }
    }

    private func channelInfoURL() async throws -> String {
        // 1) 현재 채널 or DB에서 channelId로 찾아 handle 사용 — 핸들 형식(UC_..) 채널은 실제 채널로 교정
        let ch = channel ?? SubscribedChannel.loadAll().first(where: { $0.id == channelId })
        if let handle = ch?.handle, !handle.isEmpty {
            return "https://www.youtube.com/\(handle)"
        }

        // 2) 같은 이름/토큰의 보관함 아이템에서 실제 UC 채널 ID(24자) 탐색 — 잘못 저장된 핸들 형식 교정
        if let realId = items.first(where: {
            $0.channelName != channelName
                && LibraryCacheService.isRealChannelID($0.channelId)
                && $0.channelId != channelId
                && nameTokensMatch($0.channelName, channelName)
        })?.channelId ?? items.first(where: {
            $0.channelName == channelName
                && LibraryCacheService.isRealChannelID($0.channelId)
                && $0.channelId != channelId
        })?.channelId {
            return "https://www.youtube.com/channel/\(realId)"
        }

        // 3) 구독 채널 목록에서 이름/토큰 기반으로 handle/실제 ID 탐색
        if let match = SubscribedChannel.loadAll().first(where: {
            nameTokensMatch($0.name, channelName)
        }) {
            if let handle = match.handle, !handle.isEmpty {
                return "https://www.youtube.com/\(handle)"
            }
            if LibraryCacheService.isRealChannelID(match.id) {
                return "https://www.youtube.com/channel/\(match.id)"
            }
        }

        // 4) 실제 채널 ID(UC로 시작 + 22자)만 channel/ 경로로 구성
        if LibraryCacheService.isRealChannelID(channelId) {
            return "https://www.youtube.com/channel/\(channelId)"
        }
        if channelId.hasPrefix("@") {
            return "https://www.youtube.com/\(channelId)/videos"
        }
        // 5) 핸들/이름 기반 폴백
        if let encoded = channelName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return "https://www.youtube.com/@\(encoded)/videos"
        }
        return "https://www.youtube.com/@\(channelName)/videos"
    }

    /// 두 채널 이름의 유효 토큰(한글/영문 단어) 공통 여부 확인 — "지무비 G Movie" vs "지무비 : G Movie" 매칭
    private func nameTokensMatch(_ a: String, _ b: String) -> Bool {
        LibraryCacheService.nameTokensMatch(a, b)
    }

    private func refreshChannelInfo() {
        isRefreshing = true
        errorMessage = nil
        DebugLogManager.shared?.append("[Channel] ▶️ 채널 정보 갱신 시작: \(channelName) (\(channelId))")
        Task {
            do {
                let service = ChannelFetchService()
                let url = try await channelInfoURL()
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
                                DebugLogManager.shared?.append("[Channel] 🖼️ 아바타 캐시 갱신 완료 (\(img.size.width)x\(img.size.height))")
                            }
                        }
                    }
                    isRefreshing = false
                    DebugLogManager.shared?.append("[Channel] ✅ 채널 정보 갱신 완료: \(fetched.name) (구독자 \(fetched.subscriberCount ?? 0), 영상 \(fetched.videoCount)개)")
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: Constants.channelInfoDidUpdateNotification, object: nil, userInfo: ["channelId": channelId])
                }
            } catch {
                await MainActor.run {
                    errorMessage = "갱신 실패"
                    isRefreshing = false
                    DebugLogManager.shared?.append("[Channel] ❌ 채널 정보 갱신 실패: \(error.localizedDescription) (channelId=\(channelId))")
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
