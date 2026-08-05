import Foundation
import ComposableArchitecture

@Reducer
struct ReportReducer {
    @ObservableState
    struct State: Equatable {
        var stats: DigestStats?
        var loading = false
    }

    enum Action: Equatable {
        case generateReport(ReportPeriod)
        case reportLoaded(DigestStats)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .generateReport(period):
                state.loading = true
                return .run { send in
                    let items = await LibraryCacheService.shared.loadItems()
                    let history = DatabaseManager.shared.loadDownloadHistory()
                    let stats = await DigestService.collectStats(period: period, items: items, history: history)
                    var s = stats
                    if period == .week {
                        s.aiNarrative = await DigestService.generateNarrative(stats: stats)
                    }
                    await send(.reportLoaded(s))
                }

            case let .reportLoaded(stats):
                state.stats = stats
                state.loading = false
                return .none
            }
        }
    }
}