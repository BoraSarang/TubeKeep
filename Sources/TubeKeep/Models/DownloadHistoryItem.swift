import SwiftUI

struct DownloadHistoryItem: Identifiable, Equatable {
    let id: Int64
    let videoId: String?
    let title: String
    let channelName: String?
    let url: String
    let formatLabel: String?
    let resolution: Int?
    let fileSize: Int64?
    let filePath: String?
    let downloadedAt: Date
    let status: String

    var statusBadgeText: String {
        status == "completed" ? "완료" : "실패"
    }

    var statusBadgeColor: Color {
        status == "completed" ? .green : .red
    }

    var formattedSize: String {
        guard let size = fileSize, size > 0 else { return "-" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: downloadedAt)
    }
}
