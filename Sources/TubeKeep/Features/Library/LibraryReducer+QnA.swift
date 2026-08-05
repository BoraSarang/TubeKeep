import Foundation
import ComposableArchitecture

extension LibraryReducer {
    static func handleQnAAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .openQnA(videoId):
            state.qnaSelectedVideoId = videoId
            state.qnaHistoryItems = []
            state.qnaShowSheet = true
            return .send(.showSummary(videoId))

        case .closeQnA:
            state.qnaShowSheet = false
            state.qnaSelectedVideoId = nil
            state.qnaHistoryItems = []
            return .none

        case let .askQuestion(videoId, question):
            state.qnaLoading = true
            state.qnaError = nil
            return .run { send in
                guard let item = await LibraryCacheService.shared.loadItems().first(where: { $0.id == videoId }),
                      let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                      let transcript = data.transcript, !transcript.isEmpty else {
                    await send(.qnaFailed("자막이 없습니다"))
                    return
                }
                let openRouterKey = Settings.loadAPIKeys().openRouter
                do {
                    let response = try await QAService.shared.ask(
                        videoId: videoId,
                        question: question,
                        transcript: transcript,
                        title: item.title,
                        openRouterAPIKey: openRouterKey
                    )
                    await send(.qnaResponseReceived(response))
                } catch {
                    await send(.qnaFailed(error.localizedDescription))
                }
            }

        case .qnaResponseReceived:
            state.qnaLoading = false
            if let videoId = state.qnaSelectedVideoId {
                return .send(.loadQnAHistory(videoId))
            }
            return .none

        case let .qnaFailed(error):
            state.qnaLoading = false
            state.qnaError = error
            return .none

        case let .loadQnAHistory(videoId):
            return .run { send in
                let items = await QAService.shared.loadHistory(videoId: videoId)
                await send(.qnaHistoryLoaded(items))
            }

        case let .qnaHistoryLoaded(items):
            state.qnaHistoryItems = items
            return .none

        case let .deleteQnAHistoryItem(id):
            let selectedVideoId = state.qnaSelectedVideoId
            return .run { send in
                await QAService.shared.deleteHistory(id: id)
                if let videoId = selectedVideoId {
                    await send(.loadQnAHistory(videoId))
                }
            }

        case let .deleteAllQnAHistory(videoId):
            return .run { send in
                await QAService.shared.deleteAllHistory(videoId: videoId)
                await send(.qnaHistoryLoaded([]))
            }

        case let .seekToTimestamp(time):
            NotificationCenter.default.post(name: .seekToTime, object: time)
            return .none

        default: return .none
        }
    }
}
