import Foundation
import SwiftData

@MainActor
enum SwiftDataMigration {
    private static let migratedKey = "swiftDataMigrationCompleted"

    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        migrateLibrary(context: context)
        migrateSubscribedChannels(context: context)
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    private static func migrateLibrary(context: ModelContext) {
        let saveKey = "downloadLibrary"
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupSuiteName)

        var data: Data?
        if let d = sharedDefaults?.data(forKey: saveKey) {
            data = d
        } else if let d = UserDefaults.standard.data(forKey: saveKey) {
            data = d
        }

        guard let data,
              let dict = try? JSONDecoder().decode([String: LibraryItemDTO].self, from: data)
        else { return }

        for (_, dto) in dict {
            let item = LibraryItem(
                id: dto.id,
                title: dto.title,
                channelId: dto.channelId,
                channelName: dto.channelName,
                thumbnailURL: dto.thumbnailURL,
                filePath: dto.filePath,
                downloadDate: dto.downloadDate,
                uploadDate: dto.uploadDate,
                duration: dto.duration,
                channelUploadIndex: dto.channelUploadIndex,
                tags: dto.tags ?? [],
                summary: dto.summary
            )
            context.insert(item)
        }
        try? context.save()
    }

    private static func migrateSubscribedChannels(context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "subscribedChannels"),
              let channels = try? JSONDecoder().decode([SubscribedChannelDTO].self, from: data)
        else { return }

        for dto in channels {
            let channel = SubscribedChannel(
                id: dto.id,
                name: dto.name,
                handle: dto.handle,
                avatarURL: dto.avatarURL,
                subscriberCount: dto.subscriberCount,
                videoCount: dto.videoCount
            )
            context.insert(channel)
        }
        try? context.save()
    }
}

// MARK: - DTOs for Migration

private struct LibraryItemDTO: Codable {
    let id: String
    let title: String
    let channelId: String
    let channelName: String
    let thumbnailURL: String
    let filePath: String
    let downloadDate: Date
    let uploadDate: Date?
    let duration: Int?
    let channelUploadIndex: Int?
    let tags: [String]?
    let summary: String?
}

private struct SubscribedChannelDTO: Codable {
    let id: String
    let name: String
    let handle: String?
    let avatarURL: String
    let subscriberCount: Int?
    let videoCount: Int
}
