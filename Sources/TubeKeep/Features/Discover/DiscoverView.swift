import SwiftUI
import ComposableArchitecture

struct DiscoverView: View {
    let store: StoreOf<AppReducer>
    @State private var thumbnailImages: [String: NSImage] = [:]

    var body: some View {
        VStack(spacing: 0) {
            if store.library.discoverLoading && store.library.discoverVideos.isEmpty && store.library.discoverSearchText.isEmpty {
                loadingView
            } else if let error = store.library.discoverError, store.library.discoverVideos.isEmpty, store.library.discoverSearchText.isEmpty {
                errorView(error)
            } else {
                contentView
            }
        }
        .alert("Gemini API 키 필요", isPresented: Binding(
            get: { store.library.showGeminiKeyAlert },
            set: { store.send(.library(.setGeminiKeyAlert($0))) }
        )) {
            Button("키 발급 받기") {
                NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/apikey")!)
            }
            Button("설정 열기") {
                store.send(.library(.openSettingsForGeminiKey))
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("Google Gemini 모드에서는 API 키가 필요합니다.\n설정에서 API 키를 입력하거나 yTeaser 모드로 전환해 주세요.")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("트렌딩 영상을 불러오는 중...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("인터넷 연결 필요")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(error)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("다시 시도") {
                store.send(.library(.refreshTrending))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        let isProfile = store.library.isShowingProfileRecommendations
        let isSearching = !store.library.discoverSearchText.isEmpty
        let videos: [TrendingVideo]
        if isProfile {
            videos = store.library.profileRecommendations
        } else if isSearching {
            videos = store.library.discoverSearchResults
        } else {
            videos = store.library.discoverVideos[store.library.discoverCategory] ?? []
        }
        let downloadedIds = Set(store.library.items.map(\.id))
        let libraryItems = Dictionary(uniqueKeysWithValues: store.library.items.map { ($0.id, $0) })
        return Group {
            if isProfile && store.library.profileRecommendationsLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("취향 분석 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching && videos.isEmpty && !store.library.discoverSearching {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("'\(store.library.discoverSearchText)' 검색 결과 없음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if videos.isEmpty && !isProfile {
                VStack(spacing: 8) {
                    Text("영상을 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if videos.isEmpty && isProfile {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("아직 추천할 데이터가 부족해요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("영상을 다운로드하고 태그가 추가되면 맞춤 추천을 제공합니다")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 16)
                    ], spacing: 16) {
                        ForEach(videos) { video in
                            let isDownloaded = downloadedIds.contains(video.id)
                            let localItem = isDownloaded ? libraryItems[video.id] : nil
                            DiscoverCard(
                                video: video,
                                thumbnail: thumbnailImages[video.id],
                                isDownloaded: isDownloaded,
                                localFilePath: localItem?.filePath,
                                onOpen: { openVideo(video, localItem: localItem) },
                                onAddToQueue: { addToQueue(video) }
                            )
                            .onAppear { loadThumbnail(for: video) }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func openVideo(_ video: TrendingVideo, localItem: LibraryItem? = nil) {
        let playerItem = PlayerItem(
            fileURL: localItem.map { URL(fileURLWithPath: $0.filePath) },
            title: video.title,
            videoId: video.id
        )
        NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem)
    }

    private func addToQueue(_ video: TrendingVideo) {
        NotificationCenter.default.post(name: Constants.openDownloaderWindowNotification, object: nil)
        store.send(.home(.autoFetchInfo(video.webpageURL)))
    }

    private func loadThumbnail(for video: TrendingVideo) {
        guard thumbnailImages[video.id] == nil else { return }
        let service = LibraryCacheService.shared
        Task {
            if let cached = service.cachedThumbnail(for: video.id) {
                await MainActor.run { thumbnailImages[video.id] = cached }
                return
            }
            if let data = await service.loadThumbnail(from: video.thumbnailURL, videoId: video.id),
               let img = NSImage(data: data) {
                await MainActor.run { thumbnailImages[video.id] = img }
            }
        }
    }
}

// MARK: - Discover Card

struct DiscoverCard: View {
    let video: TrendingVideo
    let thumbnail: NSImage?
    let isDownloaded: Bool
    let localFilePath: String?
    let onOpen: () -> Void
    let onAddToQueue: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnailView
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topTrailing) {
                    if isDownloaded && !isHovering {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .background(Circle().fill(AppColors.success).frame(width: 14, height: 14))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(6)
                    }
                }
                .overlay {
                    if isHovering {
                        Color.black.opacity(0.35)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .overlay(alignment: .center) {
                    if isHovering {
                        VStack(spacing: 8) {
                            Button {
                                onOpen()
                            } label: {
                                Label(isDownloaded ? "재생" : "열기", systemImage: "play")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 110, height: 26)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .controlSize(.small)

                            if isDownloaded {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("다운로드 완료")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 110, height: 26)
                                .background(Capsule().fill(AppColors.success))
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            } else {
                                Button {
                                    onAddToQueue()
                                } label: {
                                    Label("다운로드", systemImage: "arrow.down.to.line")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 110, height: 26)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.accentColor)
                                .controlSize(.small)
                            }
                        }
                        .transition(.opacity)
                    }
                }

            Text(video.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .truncationMode(.tail)

            HStack(spacing: 4) {
                Text(video.channel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if !video.formattedViews.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "eye")
                            .font(.system(size: 8))
                        Text(video.formattedViews)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }
                if !video.formattedDuration.isEmpty {
                    Text(video.formattedDuration)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var thumbnailView: some View {
        Color.clear
            .overlay {
                if let img = thumbnail {
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
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()
    }
}
