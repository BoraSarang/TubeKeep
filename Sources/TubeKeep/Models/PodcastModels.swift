import Foundation

struct PodcastScript: Codable, Equatable {
    let segments: [PodcastSegment]
}

struct PodcastSegment: Codable, Equatable {
    let speaker: String
    let text: String
}

struct PodcastResult: Equatable {
    let audioPath: String
    let script: PodcastScript
    let duration: TimeInterval
    let engineName: String
}
