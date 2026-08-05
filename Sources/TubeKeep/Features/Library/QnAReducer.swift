import Foundation
import ComposableArchitecture

@Reducer
struct QnAReducer {
    @ObservableState
    struct State: Equatable {
        var historyItems: [QAHistoryItem] = []
        var loading = false
        var error: String?
        var selectedVideoId: String?
        var showSheet = false
    }

    enum Action: Equatable {
        case open(String)
        case resetForVideo(String)
        case close
        case askQuestion(videoId: String, question: String)
        case qnaResponseReceived(QAResponse)
        case qnaFailed(String)
        case loadQnAHistory(String)
        case qnaHistoryLoaded([QAHistoryItem])
        case deleteQnAHistoryItem(Int64)
        case deleteAllQnAHistory(String)
        case seekToTimestamp(Double)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .open(videoId):
                state.selectedVideoId = videoId
                state.historyItems = []
                state.showSheet = true
                return .none

            case let .resetForVideo(videoId):
                if state.selectedVideoId != videoId {
                    state.historyItems = []
                }
                state.selectedVideoId = videoId
                return .none

            case .close:
                state.showSheet = false
                state.selectedVideoId = nil
                state.historyItems = []
                return .none

            case let .askQuestion(videoId, question):
                state.loading = true
                state.error = nil
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
                state.loading = false
                if let videoId = state.selectedVideoId {
                    return .send(.loadQnAHistory(videoId))
                }
                return .none

            case let .qnaFailed(error):
                state.loading = false
                state.error = error
                return .none

            case let .loadQnAHistory(videoId):
                return .run { send in
                    let items = await QAService.shared.loadHistory(videoId: videoId)
                    await send(.qnaHistoryLoaded(items))
                }

            case let .qnaHistoryLoaded(items):
                state.historyItems = items
                return .none

            case let .deleteQnAHistoryItem(id):
                let selectedVideoId = state.selectedVideoId
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
                let videoId = state.selectedVideoId
                return .run { send in
                    guard let videoId,
                          let item = await LibraryCacheService.shared.loadItems().first(where: { $0.id == videoId }) else {
                        return
                    }
                    let playerItem = PlayerItem(
                        fileURL: URL(fileURLWithPath: item.filePath),
                        title: item.title,
                        videoId: item.id,
                        duration: Double(item.duration ?? 0),
                        initialSeekTime: time
                    )
                    await MainActor.run {
                        NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem)
                    }
                }
            }
        }
    }
}