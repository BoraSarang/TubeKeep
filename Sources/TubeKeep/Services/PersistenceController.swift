import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("com.borasarang.tubekeep", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let storeURL = dir.appendingPathComponent("default.store")
            config = ModelConfiguration(url: storeURL)
        }
        do {
            container = try ModelContainer(for: LibraryItem.self, SubscribedChannel.self, configurations: config)
        } catch {
            fatalError("SwiftData 컨테이너 초기화 실패: \(error)")
        }
    }

    var context: ModelContext {
        container.mainContext
    }
}
