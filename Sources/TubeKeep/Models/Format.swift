import Foundation

struct Format: Identifiable, Equatable, Codable {
    let id: String
    let label: String
    let height: Int
    let ext: String
    let codec: String
    let filesize: Int64?
    let fps: Int?
    let isVideoOnly: Bool
    let isAudioOnly: Bool

    var isCombined: Bool { !isVideoOnly && !isAudioOnly }
    var isMP4: Bool { ext == "mp4" }

    var filesizeFormatted: String {
        guard let f = filesize else { return "용량 미확인" }
        if f < 1_000_000 {
            return String(format: "%.1f KB", Double(f) / 1_000)
        }
        if f < 1_000_000_000 {
            return String(format: "%.1f MB", Double(f) / 1_000_000)
        }
        return String(format: "%.1f GB", Double(f) / 1_000_000_000)
    }

    var isDefault: Bool {
        height == Constants.defaultResolution
    }

    var resolutionLabel: String {
        if height >= 2160 { return "4K" }
        if height >= 1440 { return "2K" }
        if height >= 1080 { return "1080p" }
        if height >= 720 { return "720p" }
        if height >= 480 { return "480p" }
        if height >= 360 { return "360p" }
        if height >= 240 { return "240p" }
        return "\(height)p"
    }

    static func best(forHeight targetHeight: Int, from formats: [Format]) -> Format? {
        // 1순위: combined mp4 (영상+소리 통합, re-encode 없음)
        if let f = formats.first(where: { $0.height == targetHeight && $0.isCombined && $0.isMP4 }) {
            return f
        }
        // 2순위: combined any (webm 등 포함 — remux-video mp4가 mp4로 변환)
        if let f = formats.first(where: { $0.height == targetHeight && $0.isCombined }) {
            return f
        }
        // 3순위: target보다 높은 해상도에서 combined 찾기
        let higherCombined = formats
            .filter { $0.height > targetHeight && $0.height > 0 && $0.isCombined }
            .sorted { $0.height < $1.height }
        if let f = higherCombined.first { return f }
        // 4순위: video-only mp4 (audio는 buildDownloadArgs에서 +bestaudio 처리)
        if let f = formats.first(where: { $0.height == targetHeight && $0.isVideoOnly && $0.isMP4 }) {
            return f
        }
        // 5순위: height 매칭 any format
        if let f = formats.first(where: { $0.height == targetHeight }) {
            return f
        }
        return formats.first
    }
}
