import SwiftUI
import Foundation

private struct ImageCacheKey: EnvironmentKey {
    static let defaultValue: LibraryCacheService = .shared
}

extension EnvironmentValues {
    var imageCache: LibraryCacheService {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}