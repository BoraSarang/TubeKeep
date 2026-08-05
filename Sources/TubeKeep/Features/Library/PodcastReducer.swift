import Foundation
import ComposableArchitecture

@Reducer
struct PodcastReducer {
    @ObservableState
    struct State: Equatable {
        var generatingIds: Set<String> = []
        var progressMessage = ""
        var playingId: String?
        var error: String?
        var availableIds: Set<String> = []
        var lastEngine: String?
    }

    enum Action: Equatable {
        case generatePodcast(String)
        case setAvailableIds(Set<String>)
        case podcastProgressUpdate(videoId: String, message: String)
        case podcastGenerated(videoId: String, result: PodcastResult)
        case podcastGenerationFailed(videoId: String, error: String)
        case playPodcast(String)
        case pausePodcast
        case stopPodcast
        case deletePodcast(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .generatePodcast(videoId):
                state.generatingIds.insert(videoId)
                state.error = nil
                return .run { send in
                    let openRouterKey = Settings.loadAPIKeys().openRouter
                    do {
                        let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId)
                        guard let transcript = data?.transcript, !transcript.isEmpty else {
                            await send(.podcastGenerationFailed(videoId: videoId, error: "자막이 없어 팟캐스트를 생성할 수 없습니다."))
                            return
                        }
                        let item = await LibraryCacheService.shared.loadItems().first { $0.id == videoId }
                        let title = item?.title ?? ""
                        let channel = item?.channelName ?? ""
                        let progress: @MainActor @Sendable (String) -> Void = { msg in
                            Task { @MainActor in
                                await send(.podcastProgressUpdate(videoId: videoId, message: msg))
                            }
                        }
                        let result = try await PodcastService.shared.generatePodcast(
                            videoId: videoId,
                            title: title,
                            channel: channel,
                            transcript: transcript,
                            openRouterAPIKey: openRouterKey,
                            progress: progress
                        )
                        await send(.podcastGenerated(videoId: videoId, result: result))
                    } catch {
                        await send(.podcastGenerationFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

            case let .setAvailableIds(ids):
                state.availableIds = ids
                return .none

            case let .podcastProgressUpdate(_, message):
                state.progressMessage = message
                return .none

            case let .podcastGenerated(videoId, result):
                state.generatingIds.remove(videoId)
                state.progressMessage = ""
                state.availableIds.insert(videoId)
                state.lastEngine = result.engineName
                return .none

            case let .podcastGenerationFailed(videoId, error):
                state.generatingIds.remove(videoId)
                state.progressMessage = ""
                state.error = error
                return .none

            case let .playPodcast(videoId):
                state.playingId = videoId
                return .merge(
                    .run { _ in
                        do {
                            try await PodcastService.shared.playPodcast(videoId: videoId)
                        } catch {
                            #if DEBUG
                            Task { @MainActor in
                                DebugLogManager.shared?.append("[Podcast] 재생 실패: \(error.localizedDescription)")
                            }
                            #endif
                        }
                    },
                    .run { send in
                        for await _ in NotificationCenter.default.notifications(named: .podcastPlaybackFinished) {
                            await send(.stopPodcast)
                        }
                    }
                )

            case .pausePodcast:
                return .run { _ in
                    await PodcastService.shared.pausePodcast()
                }

            case .stopPodcast:
                state.playingId = nil
                return .run { _ in
                    await PodcastService.shared.stopPodcast()
                }

            case let .deletePodcast(videoId):
                if state.playingId == videoId {
                    state.playingId = nil
                }
                state.availableIds.remove(videoId)
                return .run { _ in
                    try? await PodcastService.shared.deletePodcast(videoId: videoId)
                }
            }
        }
    }
}