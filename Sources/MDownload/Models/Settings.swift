import Foundation

struct Settings: Equatable, Codable {
    var concurrentDownloads: Int = Constants.defaultConcurrentDownloads
    var outputDirectory: String = Constants.defaultOutputDirectory
    var filenameTemplate: String = Constants.defaultFilenameTemplate
    var limitRate: Int = 0
    var playSoundOnComplete: Bool = true
    var alwaysOnTop: Bool = false
    var clipboardMonitoring: Bool = true
    var showOnlyVideo: Bool = true
    var defaultResolution: Int = Constants.defaultResolution
    var maxRetries: Int = Constants.defaultMaxRetries
    var launchAtLogin: Bool = false
    var maxUploadCheck: Int = Constants.defaultMaxUploadCheck
    var skipIndexOnFailure: Bool = false

    var limitRateArg: String? {
        guard limitRate > 0 else { return nil }
        return "\(limitRate)M"
    }
}
