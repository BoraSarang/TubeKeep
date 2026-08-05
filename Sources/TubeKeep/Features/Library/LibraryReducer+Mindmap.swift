import Foundation
import ComposableArchitecture

extension LibraryReducer {
    static func handleMindmapAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .generateMindmap(videoId):
            guard let item = state.items.first(where: { $0.id == videoId }),
                  let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                  let transcript = data.transcript, !transcript.isEmpty else {
                state.mindmapError = "자막이 없습니다"
                return .none
            }
            if let mindmapData = data.mindmap,
               let existing = try? JSONDecoder().decode(MindmapNode.self, from: mindmapData) {
                state.mindmapNode = existing
                state.mindmapShow = true
                return .none
            }
            state.mindmapLoading = true
            state.mindmapError = nil
            state.mindmapShow = true
            let openRouterKey = Settings.loadAPIKeys().openRouter
            let mindmapTitle = item.title
            let mindmapChannel = item.channelName
            return .run { send in
                do {
                    let node = try await MindmapService.shared.generate(
                        videoId: videoId,
                        transcript: transcript,
                        title: mindmapTitle,
                        channel: mindmapChannel,
                        openRouterAPIKey: openRouterKey
                    )
                    await send(.mindmapResult(node))
                } catch {
                    await send(.mindmapFailed(error.localizedDescription))
                }
            }

        case let .mindmapResult(node):
            state.mindmapLoading = false
            state.mindmapNode = node
            return .none

        case let .mindmapFailed(error):
            state.mindmapLoading = false
            state.mindmapError = error
            DebugLogManager.shared?.append("[MindmapRedux] ❌ mindmapFailed — \(error)")
            return .none

        case .toggleMindmap:
            state.mindmapShow.toggle()
            if !state.mindmapShow {
                state.mindmapNode = nil
                state.mindmapError = nil
            }
            return .none

        default: return .none
        }
    }
}
