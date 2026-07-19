import Foundation
import SwiftData

@Model
final class SubscribedChannel: Identifiable, @unchecked Sendable {
    @Attribute(.unique) var id: String
    var name: String
    var handle: String?
    var avatarURL: String
    var subscriberCount: Int?
    var videoCount: Int

    init(id: String, name: String, handle: String?, avatarURL: String, subscriberCount: Int?, videoCount: Int) {
        self.id = id
        self.name = name
        self.handle = handle
        self.avatarURL = avatarURL
        self.subscriberCount = subscriberCount
        self.videoCount = videoCount
    }
}

extension SubscribedChannel: Equatable {
    static func == (lhs: SubscribedChannel, rhs: SubscribedChannel) -> Bool {
        lhs.id == rhs.id
    }
}

extension SubscribedChannel {
    @MainActor
    static func loadAll() -> [SubscribedChannel] {
        let context = PersistenceController.shared.context
        let descriptor = FetchDescriptor<SubscribedChannel>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func saveAll(_ channels: [SubscribedChannel]) {
        let context = PersistenceController.shared.context
        let descriptor = FetchDescriptor<SubscribedChannel>(sortBy: [])
        if let existing = try? context.fetch(descriptor) {
            for item in existing { context.delete(item) }
        }
        for channel in channels { context.insert(channel) }
        try? context.save()
    }
}
