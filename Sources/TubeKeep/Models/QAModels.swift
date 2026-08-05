import Foundation

struct QAResponse: Codable, Equatable {
    let question: String
    let answer: String
    let timestamps: [QATimestamp]
}

struct QATimestamp: Codable, Equatable, Identifiable {
    var id: String { "\(startTime)" }
    let time: String       // "1:23" 형식
    let startTime: Double  // 초 단위
    let description: String
}

struct QAHistoryItem: Identifiable, Equatable {
    let id: Int64
    let videoId: String
    let question: String
    let answer: String
    let timestamps: [QATimestamp]
    let createdAt: Date
}
