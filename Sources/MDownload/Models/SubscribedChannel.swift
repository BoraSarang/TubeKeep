import Foundation

struct SubscribedChannel: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let handle: String?
    let avatarURL: String
    let subscriberCount: Int?
    let videoCount: Int
}

extension SubscribedChannel {
    static func loadAll() -> [SubscribedChannel] {
        guard let data = UserDefaults.standard.data(forKey: "subscribedChannels"),
              let channels = try? JSONDecoder().decode([SubscribedChannel].self, from: data)
        else { return [] }
        return channels
    }

    static func saveAll(_ channels: [SubscribedChannel]) {
        guard let data = try? JSONEncoder().encode(channels) else { return }
        UserDefaults.standard.set(data, forKey: "subscribedChannels")
    }
}
