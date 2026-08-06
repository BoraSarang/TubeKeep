import Foundation
import SwiftData

@Model
final class ClipItem: Identifiable {
    @Attribute(.unique) var id: String
    var videoId: String
    var channelName: String?
    var title: String
    var filePath: String
    var thumbnailPath: String?
    var start: Double
    var end: Double
    var duration: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        videoId: String,
        channelName: String? = nil,
        title: String,
        filePath: String,
        thumbnailPath: String? = nil,
        start: Double,
        end: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.videoId = videoId
        self.channelName = channelName
        self.title = title
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.start = start
        self.end = end
        self.duration = Int(end - start)
        self.createdAt = createdAt
    }
}

extension ClipItem: @unchecked Sendable {}

extension ClipItem: Equatable {
    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ClipError: LocalizedError {
    case invalidRange
    case duplicateRange
    case encodeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            return "클립 시작점이 끝점보다 늦습니다"
        case .duplicateRange:
            return "이미 저장된 구간입니다"
        case let .encodeFailed(code):
            return "ffmpeg 인코딩 실패 (exit \(code))"
        }
    }
}
