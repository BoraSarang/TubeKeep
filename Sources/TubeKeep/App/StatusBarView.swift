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
        var speedTestState: SpeedTestState = .idle

        enum SpeedTestState: Equatable {
            case idle
            case measuring
            case completed(kbps: Double)
        }

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
        case startSpeedTest
        case speedTestUpdate(Double)
        case speedTestComplete
        case updateStatusText(String)
        case updateStatusDetail(String)
        #if DEBUG
        case startStatusBarTest
        case statusBarTestTick(Int)  // elapsed seconds
        #endif
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
            case .startSpeedTest:
                state.speedTestState = .measuring
                return .none
            case let .speedTestUpdate(kbps):
                state.speedTestState = .completed(kbps: kbps)
                return .run { send in
                    try await Task.sleep(for: .seconds(5))
                    await send(.speedTestComplete)
                }
            case .speedTestComplete:
                state.speedTestState = .idle
                return .none

            #if DEBUG
            case .startStatusBarTest:
                state.hasActiveDownloads = true
                state.activeCount = 3
                state.totalCount = 8
                state.downloadSpeed = "3.5 MB/s"
                state.downloadETA = "10초"
                state.completedCount = 0
                return .run { send in
                    for tick in 0..<20 {  // 0.5s interval × 20 = 10초
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.statusBarTestTick(tick))
                    }
                    await send(.setActiveDownloads(false))
                }

            case let .statusBarTestTick(tick):
                let t = Double(tick)
                let speedValue = 3.0 + sin(t * 0.5) * 2.0 + Double.random(in: -0.5...0.5)
                let speedStr = String(format: "%.1f MB/s", speedValue)
                let remainingSec = max(1, Int(10.0 - t * 0.5))
                let etaStr = "\(remainingSec)초"
                state.downloadSpeed = speedStr
                state.downloadETA = etaStr
                state.activeCount = tick < 15 ? 3 : (tick < 18 ? 1 : 0)
                state.totalCount = 8
                state.completedCount = tick < 4 ? 0 : (tick < 10 ? 2 : (tick < 16 ? 5 : 7))
                state.hasActiveDownloads = state.activeCount > 0
                return .none
            #endif
            }
        }
    }
}
