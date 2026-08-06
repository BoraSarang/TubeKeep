import Foundation
import SwiftData

@MainActor
enum SwiftDataMigration {
    private static let migratedKey = "swiftDataMigrationCompleted"

    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        let libraryOK = migrateLibrary(context: context)
        let channelsOK = migrateSubscribedChannels(context: context)
        if libraryOK && channelsOK {
            UserDefaults.standard.set(true, forKey: migratedKey)
        } else {
            DebugLogManager.shared?.append("[Migration] 마이그레이션 실패 (library:\(libraryOK) channels:\(channelsOK)) — 다음 실행에서 재시도")
        }
    }

    private static func migrateLibrary(context: ModelContext) -> Bool {
        let saveKey = "downloadLibrary"
        let sharedDefaults = UserDefaults(suiteName: Constants.appGroupSuiteName)

        var data: Data?
        if let d = sharedDefaults?.data(forKey: saveKey) {
            data = d
        } else if let d = UserDefaults.standard.data(forKey: saveKey) {
            data = d
        }

        guard let data else { return true }

        guard let dict = try? JSONDecoder().decode([String: LibraryItemDTO].self, from: data) else {
            DebugLogManager.shared?.append("[Migration] downloadLibrary 디코드 실패 — 기존 데이터 형식 불일치")
            return false
        }

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
        do {
            try context.save()
            return true
        } catch {
            DebugLogManager.shared?.append("[Migration] 라이브러리 저장 실패: \(error)")
            return false
        }
    }

    private static func migrateSubscribedChannels(context: ModelContext) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "subscribedChannels") else { return true }

        guard let channels = try? JSONDecoder().decode([SubscribedChannelDTO].self, from: data) else {
            DebugLogManager.shared?.append("[Migration] subscribedChannels 디코드 실패")
            return false
        }

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
        do {
            try context.save()
            return true
        } catch {
            DebugLogManager.shared?.append("[Migration] 채널 저장 실패: \(error)")
            return false
        }
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
