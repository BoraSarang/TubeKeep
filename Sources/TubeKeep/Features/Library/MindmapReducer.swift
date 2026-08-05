import Foundation
import ComposableArchitecture

@Reducer
struct MindmapReducer {
    @ObservableState
    struct State: Equatable {
        var node: MindmapNode?
        var loading = false
        var error: String?
        var show = false
    }

    enum Action: Equatable {
        case generateMindmap(String)
        case mindmapResult(MindmapNode)
        case mindmapFailed(String)
        case toggleMindmap
        case resetForVideo(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .generateMindmap(videoId):
                guard let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                      let transcript = data.transcript, !transcript.isEmpty else {
                    state.error = "자막이 없습니다"
                    return .none
                }
                if let mindmapData = data.mindmap,
                   let existing = try? JSONDecoder().decode(MindmapNode.self, from: mindmapData) {
                    state.node = existing
                    state.show = true
                    return .none
                }
                state.loading = true
                state.error = nil
                state.show = true
                let openRouterKey = Settings.loadAPIKeys().openRouter
                return .run { send in
                    let item = await LibraryCacheService.shared.loadItems().first { $0.id == videoId }
                    let title = item?.title ?? ""
                    let channel = item?.channelName ?? ""
                    do {
                        let node = try await MindmapService.shared.generate(
                            videoId: videoId,
                            transcript: transcript,
                            title: title,
                            channel: channel,
                            openRouterAPIKey: openRouterKey
                        )
                        await send(.mindmapResult(node))
                    } catch {
                        await send(.mindmapFailed(error.localizedDescription))
                    }
                }

            case let .mindmapResult(node):
                state.loading = false
                state.node = node
                return .none

            case let .mindmapFailed(error):
                state.loading = false
                state.error = error
                DebugLogManager.shared?.append("[MindmapReducer] ❌ mindmapFailed — \(error)")
                return .none

            case .toggleMindmap:
                state.show.toggle()
                if !state.show {
                    state.node = nil
                    state.error = nil
                }
                return .none

            case let .resetForVideo(videoId):
                state.node = nil
                state.error = nil
                state.loading = false
                state.show = false
                if let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                   let mindmapData = data.mindmap,
                   let existing = try? JSONDecoder().decode(MindmapNode.self, from: mindmapData) {
                    state.node = existing
                    state.show = true
                }
                return .none
            }
        }
    }
}