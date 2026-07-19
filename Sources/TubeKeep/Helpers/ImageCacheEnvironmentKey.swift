import SwiftUI
import Foundation

private struct ImageCacheKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: LibraryCacheService = LibraryCacheService.shared
}

extension EnvironmentValues {
    var imageCache: LibraryCacheService {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}
