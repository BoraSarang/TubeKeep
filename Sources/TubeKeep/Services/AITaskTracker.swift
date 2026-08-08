import Foundation

final class AITaskTracker: @unchecked Sendable {
    static let shared = AITaskTracker()
    private let lock = NSLock()
    private var activeCount = 0

    var isBusy: Bool {
        lock.withLock { activeCount > 0 }
    }

    func begin() {
        lock.withLock { activeCount += 1 }
    }

    func end() {
        lock.withLock {
            if activeCount > 0 {
                activeCount -= 1
            }
        }
    }
}