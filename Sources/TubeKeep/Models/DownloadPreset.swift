import Foundation

struct DownloadPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var formatType: PresetFormatType
    var resolution: Int
    var includeSubtitles: Bool
    var sponsorBlock: Bool
    var embedMetadata: Bool

    enum PresetFormatType: String, Codable, CaseIterable {
        case video = "영상"
        case audio = "오디오"
    }
}
