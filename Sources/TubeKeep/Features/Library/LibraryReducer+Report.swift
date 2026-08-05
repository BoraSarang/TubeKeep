import Foundation
import ComposableArchitecture

extension LibraryReducer {
    static func handleReportAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .generateReport(period):
            state.reportLoading = true
            let items = state.items
            let history = DatabaseManager.shared.loadDownloadHistory()
            return .run { send in
                let stats = await DigestService.collectStats(period: period, items: items, history: history)
                var s = stats
                if period == .week {
                    s.aiNarrative = await DigestService.generateNarrative(stats: stats)
                }
                await send(.reportLoaded(s))
            }

        case let .reportLoaded(stats):
            state.reportStats = stats
            state.reportLoading = false
            return .none

        default: return .none
        }
    }
}
