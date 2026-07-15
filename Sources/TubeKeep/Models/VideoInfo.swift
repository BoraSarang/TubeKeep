import Foundation

struct VideoInfo: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let channel: String
    let channelId: String
    let duration: TimeInterval
    let uploadDate: String
    let thumbnailURL: String
    let webpageURL: String
    let isPlaylist: Bool
    let playlistTitle: String?
    let playlistCount: Int?

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        guard uploadDate.count == 8 else { return uploadDate }
        let y = uploadDate.prefix(4)
        let m = uploadDate.dropFirst(4).prefix(2)
        let d = uploadDate.dropFirst(6).prefix(2)
        return "\(y)-\(m)-\(d)"
    }
}
