import Foundation
import ComposableArchitecture

extension LibraryReducer {
    static func handlePodcastAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .generatePodcast(videoId):
            guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
            state.podcastGeneratingIds.insert(videoId)
            state.podcastError = nil
            // 요약 팝업 열기
            state.librarySummaryVideoId = videoId
            state.librarySummaryLoading = false
            if let existing = item.summary, !existing.isEmpty, !existing.hasPrefix("요약 실패") {
                state.librarySummaryText = existing
            } else {
                state.librarySummaryText = nil
            }
            let podcastTitle = item.title
            let podcastChannel = item.channelName
            return .run { send in
                let openRouterKey = Settings.loadAPIKeys().openRouter
                do {
                    let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId)
                    guard let transcript = data?.transcript, !transcript.isEmpty else {
                        await send(.podcastGenerationFailed(videoId, "자막이 없어 팟캐스트를 생성할 수 없습니다."))
                        return
                    }
                    let progress: @MainActor @Sendable (String) -> Void = { msg in
                        Task { @MainActor in
                            await send(.podcastProgressUpdate(videoId: videoId, message: msg))
                        }
                    }
                    let result = try await PodcastService.shared.generatePodcast(
                        videoId: videoId,
                        title: podcastTitle,
                        channel: podcastChannel,
                        transcript: transcript,
                        openRouterAPIKey: openRouterKey,
                        progress: progress
                    )
                    await send(.podcastGenerated(videoId, result))
                } catch {
                    await send(.podcastGenerationFailed(videoId, error.localizedDescription))
                }
            }

        case .podcastProgressUpdate(_, let message):
            state.podcastProgressMessage = message
            return .none

        case let .podcastGenerated(videoId, result):
            state.podcastGeneratingIds.remove(videoId)
            state.podcastProgressMessage = ""
            state.podcastAvailableIds.insert(videoId)
            state.podcastLastEngine = result.engineName
            return .none

        case let .podcastGenerationFailed(videoId, error):
            state.podcastGeneratingIds.remove(videoId)
            state.podcastProgressMessage = ""
            state.podcastError = error
            return .none

        case let .playPodcast(videoId):
            state.podcastPlayingId = videoId
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
            state.podcastPlayingId = nil
            return .run { _ in
                await PodcastService.shared.stopPodcast()
            }

        case let .deletePodcast(videoId):
            if state.podcastPlayingId == videoId {
                state.podcastPlayingId = nil
            }
            state.podcastAvailableIds.remove(videoId)
            return .run { _ in
                try? await PodcastService.shared.deletePodcast(videoId: videoId)
            }

        default: return .none
        }
    }
}
