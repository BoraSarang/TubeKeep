import Foundation
import Combine

final class DebugLogManager: ObservableObject {
    nonisolated(unsafe) static var shared: DebugLogManager?

    @Published var logs: [String] = []
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func append(_ message: String) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        logs.append("[\(timestamp)] \(message)")
        #endif
    }

    func clear() {
        #if DEBUG
        logs.removeAll()
        #endif
    }
}
