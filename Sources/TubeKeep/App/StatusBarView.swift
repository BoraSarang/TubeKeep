import SwiftUI
import ComposableArchitecture

@Reducer
struct StatusBarReducer {
    @ObservableState
    struct State: Equatable {
        var statusText: String = "대기 중"
        var statusDetail: String = ""
        var downloadSpeed: String = ""
        var badgeCount: Int = 0
        var hasActiveDownloads: Bool = false
        var activeCount: Int = 0
        var totalCount: Int = 0
        var completedCount: Int = 0
        var downloadETA: String = ""
        var overallProgress: Double = 0
        var displayText: String {
            if hasActiveDownloads, !downloadSpeed.isEmpty {
                return downloadSpeed
            }
            if !statusText.isEmpty, statusText != "대기 중" {
                return statusText
            }
            if badgeCount > 0 {
                return "대기 중 \(badgeCount)"
            }
            return "대기 중"
        }

        var hasBadge: Bool { badgeCount > 0 }
    }

    enum Action: Equatable {
        case updateSpeed(String)
        case setActiveDownloads(Bool)
        case badgeIncrement
        case setBadgeCount(Int)
        case badgeReset
        case updateStatusText(String)
        case updateStatusDetail(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateSpeed(speed):
                state.downloadSpeed = speed
                state.hasActiveDownloads = !speed.isEmpty
                return .none
            case let .setActiveDownloads(active):
                state.hasActiveDownloads = active
                if !active {
                    state.downloadSpeed = ""
                }
                return .none
            case .badgeIncrement:
                state.badgeCount += 1
                return .run { send in
                    try await Task.sleep(for: .seconds(5))
                    await send(.badgeReset)
                }
            case let .setBadgeCount(count):
                state.badgeCount = count
                return .none
            case .badgeReset:
                state.badgeCount = 0
                return .none
            case let .updateStatusText(text):
                state.statusText = text
                return .none
            case let .updateStatusDetail(detail):
                state.statusDetail = detail
                return .none
            }
        }
    }
}
