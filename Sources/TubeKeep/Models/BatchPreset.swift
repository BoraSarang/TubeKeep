import Foundation

struct BatchPreset: Equatable {
    var resolution: Int = Constants.defaultResolution
    var includeSubtitles: Bool = false
    var audioOnly: Bool = false
}
