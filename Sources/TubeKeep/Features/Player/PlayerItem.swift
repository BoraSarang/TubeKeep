import Foundation

struct PlayerItem: Equatable {
    let id: UUID
    let fileURL: URL?
    let streamURL: URL?
    let title: String
    let videoId: String?
    let duration: Double

    init(fileURL: URL? = nil, streamURL: URL? = nil, title: String, videoId: String? = nil, duration: Double = 0) {
        self.id = UUID()
        self.fileURL = fileURL
        self.streamURL = streamURL
        self.title = title
        self.videoId = videoId
        self.duration = duration
    }
}

struct SubtitleCue: Identifiable, Equatable, Codable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    let text: String

    enum CodingKeys: String, CodingKey {
        case startTime, endTime, text
    }
}
