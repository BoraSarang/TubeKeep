import Foundation

final class ActivityLogStore {
    static let shared = ActivityLogStore()

    static let activityLogDidChangeNotification = Notification.Name("activityLogDidChange")

    private let logFileName = "idle_activity.log"
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.borasarang.tubekeep")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(logFileName)
    }

    private init() {}

    func append(_ message: String) {
        let line = "\(dateFormatter.string(from: Date())) | \(message)"
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            try? handle.close()
        } else {
            try? Data((line + "\n").utf8).write(to: fileURL, options: .atomic)
        }
        NotificationCenter.default.post(name: Self.activityLogDidChangeNotification, object: line)
        #if DEBUG
        DebugLogManager.shared?.append("[ActivityLog] \(line)")
        #endif
    }

    func loadRecent(limit: Int = 200) -> [String] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let lines = content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces)}
        guard lines.last?.isEmpty != false else { return lines.suffix(limit) }
        return Array(lines.dropLast().suffix(limit))
    }

    func clear() {
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        NotificationCenter.default.post(name: Self.activityLogDidChangeNotification, object: nil)
    }
}