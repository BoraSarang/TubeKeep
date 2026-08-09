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
        func closest(to height: Int, in subset: [Format]) -> Format? {
            let lower = subset.filter { $0.height < height }.sorted { $0.height > $1.height }.first
            let higher = subset.filter { $0.height > height }.sorted { $0.height < $1.height }.first
            return lower ?? higher
        }

        // 1: exact combined mp4
        if let f = formats.first(where: { $0.height == targetHeight && $0.isCombined && $0.isMP4 }) {
            return f
        }
        // 2: exact combined any
        if let f = formats.first(where: { $0.height == targetHeight && $0.isCombined }) {
            return f
        }
        // 3: combined — lower preferred, higher fallback
        let combined = formats.filter { $0.isCombined }
        if let f = closest(to: targetHeight, in: combined) { return f }
        // 4: exact video-only mp4
        if let f = formats.first(where: { $0.height == targetHeight && $0.isVideoOnly && $0.isMP4 }) {
            return f
        }
        // 5: video-only — lower preferred, higher fallback
        let videoOnly = formats.filter { $0.isVideoOnly && !$0.isAudioOnly }
        if let f = closest(to: targetHeight, in: videoOnly) { return f }
        // 6: exact any
        if let f = formats.first(where: { $0.height == targetHeight }) {
            return f
        }
        // 7: any format — lower preferred, higher fallback
        let anyVideo = formats.filter { !$0.isAudioOnly }
        if let f = closest(to: targetHeight, in: anyVideo) { return f }
        return formats.first
    }

    /// 다운로드 기본 선택: `maxHeight` 이하 포맷만 후보로, 이하가 없으면 nil.
    /// 설정 해상도를 "최대 상한"으로 간주하고 더 높은 해상도로 자동 올라가지 않는다.
    static func bestForDownload(upTo maxHeight: Int, from formats: [Format]) -> Format? {
        let candidates = formats.filter { $0.height > 0 && $0.height <= maxHeight && !$0.isAudioOnly }
        guard !candidates.isEmpty else { return nil }

        // 1: 최대 해상도 이하 combined (mp4 선호)
        let combinedMP4 = candidates.filter { $0.isCombined && $0.isMP4 }
        if let f = combinedMP4.max(by: { $0.height < $1.height }) { return f }
        let combined = candidates.filter { $0.isCombined }
        if let f = combined.max(by: { $0.height < $1.height }) { return f }

        // 2: video-only (mp4 선호)
        let videoMP4 = candidates.filter { $0.isVideoOnly && $0.isMP4 }
        if let f = videoMP4.max(by: { $0.height < $1.height }) { return f }
        let videoOnly = candidates.filter { $0.isVideoOnly }
        if let f = videoOnly.max(by: { $0.height < $1.height }) { return f }

        // 3: any
        return candidates.max(by: { $0.height < $1.height })
    }
}
