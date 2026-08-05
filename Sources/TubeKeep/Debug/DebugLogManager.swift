import Foundation
import Combine
import os.log
import AppKit

enum DebugLogLevel: String, CaseIterable {
    case ACTION = "ACTION"
    case API_REQ = "API→"
    case API_RES = "API←"
    case INFO = "INFO"
    case PERF = "PERF"
    case CACHE = "CACHE"
    case WARN = "WARN"
    case ERROR = "ERROR"
    case SYSTEM = "SYSTEM"
}

struct DebugLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: String
    let level: DebugLogLevel
    let platform: String
    let category: String
    let message: String
    let meta: String?

    var formatted: String {
        var s = "[\(timestamp)] [\(level.rawValue)] [\(platform)] [\(category)] \(message)"
        if let meta = meta, !meta.isEmpty { s += " | meta=\(meta)" }
        return s
    }
}

final class DebugLogManager: ObservableObject {
    nonisolated(unsafe) static var shared: DebugLogManager?

    @Published var logs: [DebugLogEntry] = []
    @Published var autoScroll = true
    @Published var selectedIds: Set<UUID> = []
    @Published var lastSelectedId: UUID?

    private let maxLogs = 5000
    private var autoScrollPausedUntil: Date?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var isAutoScrollPaused: Bool {
        guard let until = autoScrollPausedUntil else { return false }
        return Date() < until
    }

    func append(_ message: String) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        let category = extractCategory(from: message)
        let cleanMsg = stripCategory(from: message)
        let entry = DebugLogEntry(
            timestamp: timestamp, level: .INFO, platform: "MACOS",
            category: category, message: cleanMsg, meta: nil
        )
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
            print(entry.formatted)
            os_log("%{public}@", entry.formatted)
        }
        #endif
    }

    func push(_ level: DebugLogLevel, platform: String = "MACOS", category: String, message: String, meta: Any? = nil) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        let metaStr = maskSecrets(meta)
        let entry = DebugLogEntry(
            timestamp: timestamp, level: level, platform: platform,
            category: category, message: message, meta: metaStr
        )
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
            print(entry.formatted)
            os_log("%{public}@", entry.formatted)
        }
        #endif
    }

    func clear() {
        #if DEBUG
        logs.removeAll()
        selectedIds.removeAll()
        lastSelectedId = nil
        autoScroll = true
        #endif
    }

    func pauseAutoScroll() {
        autoScrollPausedUntil = Date().addingTimeInterval(2)
    }

    func copySelection() {
        #if DEBUG
        let text = logs.filter { selectedIds.contains($0.id) }.map { $0.formatted }.joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    func copyAll() {
        #if DEBUG
        let text = formatForAgent(logs)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    func formatForAgent(_ entries: [DebugLogEntry]) -> String {
        entries.map { $0.formatted }.joined(separator: "\n")
    }

    private func extractCategory(from message: String) -> String {
        if message.hasPrefix("[") {
            if let end = message.dropFirst().firstIndex(of: "]") {
                return String(message[message.index(after: message.startIndex)..<message.index(after: end)])
            }
        }
        return "GENERAL"
    }

    private func stripCategory(from message: String) -> String {
        if message.hasPrefix("[") {
            if let end = message.dropFirst().firstIndex(of: "]") {
                return String(message[message.index(after: end)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return message
    }

    private func maskSecrets(_ obj: Any?) -> String? {
        guard let obj = obj else { return nil }
        let str = "\(obj)"
        if str.contains("token") || str.contains("password") || str.contains("keystore") || str.contains("apiKey") || str.contains("secret") {
            return "***MASKED***"
        }
        if str.count > 500 {
            return String(str.prefix(500)) + "...(truncated)"
        }
        return str
    }
}
