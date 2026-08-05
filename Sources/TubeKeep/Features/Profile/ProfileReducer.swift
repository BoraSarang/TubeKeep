import Foundation
import ComposableArchitecture

@Reducer
struct ProfileReducer {
    @ObservableState
    struct State: Equatable {
        var profile: UserProfile?
        var isLoading = false
    }

    enum Action: Equatable {
        case refresh
        case profileUpdated(UserProfile)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                state.isLoading = true
                return .run { send in
                    let items = await LibraryCacheService.shared.loadItems()
                    let channels = await MainActor.run { SubscribedChannel.loadAll() }
                    let history = DatabaseManager.shared.loadDownloadHistory()
                    let diskUsage = LibraryCacheService.calculateDiskUsage()
                    let profile = ProfileService.calculate(items: items, channels: channels, history: history, diskUsage: diskUsage)
                    await send(.profileUpdated(profile))
                }

            case .profileUpdated(let p):
                state.profile = p
                state.isLoading = false
                return .none
            }
        }
    }
}
