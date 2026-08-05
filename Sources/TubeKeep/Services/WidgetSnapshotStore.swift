import Foundation

struct WidgetSnapshot: Codable {
    struct Active: Codable {
        let title: String
        let progress: Double
        let speed: String
    }
    struct Recent: Codable {
        let title: String
        let completedAt: Date
    }
    var active: [Active] = []
    var waiting: Int = 0
    var recentCompleted: [Recent] = []
    var updatedAt: Date = Date()

    static let groupID = "group.com.tubekeep"
    static let snapshotKey = "widget_snapshot"

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.groupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.snapshotKey)
    }
}
