import SwiftUI
import Foundation

import SwiftUI

private struct ImageCacheKey: EnvironmentKey {
    static let defaultValue: LibraryCacheService = {
        MainActor.assumeIsolated { LibraryCacheService.shared }
    }()
}

extension EnvironmentValues {
    var imageCache: LibraryCacheService {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}
