import Foundation

enum DownloadStatus: String, Equatable, Codable {
    case pending
    case downloading
    case paused
    case completed
    case failed
    case retrying
}

struct DownloadItem: Identifiable, Equatable, Codable {
    static let mediaFileExtensions: Set<String> = ["mp4", "m4a", "mkv", "webm", "mp3", "aac"]

    let id: UUID
    let videoInfo: VideoInfo
    let selectedFormat: Format
    let includeSubtitles: Bool
    let audioOnly: Bool
    var isChannelDownload: Bool = false
    var outputPath: String?
    var status: DownloadStatus
    var progress: Double
    var downloadSpeed: String
    var downloadStartTime: Date?
    var errorMessage: String?
    var retryCount: Int = 0
    var channelUploadIndex: Int
    let playlistIndex: Int?

    init(
        videoInfo: VideoInfo,
        selectedFormat: Format,
        includeSubtitles: Bool = false,
        audioOnly: Bool = false,
        isChannelDownload: Bool = false,
        channelUploadIndex: Int = 0,
        playlistIndex: Int? = nil
    ) {
        self.id = UUID()
        self.videoInfo = videoInfo
        self.selectedFormat = selectedFormat
        self.includeSubtitles = includeSubtitles
        self.audioOnly = audioOnly
        self.isChannelDownload = isChannelDownload
        self.outputPath = nil
        self.status = .pending
        self.progress = 0
        self.downloadSpeed = ""
        self.errorMessage = nil
        self.channelUploadIndex = channelUploadIndex
        self.playlistIndex = playlistIndex
    }

    var estimatedRemaining: TimeInterval? {
        guard status == .downloading,
              let startTime = downloadStartTime,
              progress > 0.01
        else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return (1.0 - progress) * elapsed / progress
    }

    var optionsLabel: String {
        var parts = [selectedFormat.label]
        if includeSubtitles { parts.append("자막") }
        if audioOnly { parts.append("AAC") }
        return parts.joined(separator: " + ")
    }

    var etaText: String {
        guard let remaining = estimatedRemaining, remaining > 0 else { return "" }
        if remaining < 60 {
            return String(format: "%.0f초", remaining)
        } else if remaining < 3600 {
            return String(format: "%.0f분", remaining / 60)
        } else {
            return String(format: "%.1f시간", remaining / 3600)
        }
    }

    var estimatedFilename: String {
        let folder = Constants.sanitizeFolderName(videoInfo.channel)
        if isChannelDownload {
            return "\(Constants.channelStorageDirectory)/\(folder)/\(String(format: "%03d", channelUploadIndex)) - \(videoInfo.title).\(videoInfo.id).mp4"
        }
        let template = Settings.loadSettings().filenameTemplate
        return "\(Constants.channelStorageDirectory)/\(folder)/\(formatFilename(template: template))"
    }

    func checkExistingFile(storageDirectory: String, template: String) -> String? {
        BookmarkManager.ensureAccess()
        let folder = Constants.sanitizeFolderName(videoInfo.channel)
        let channelDir = "\(storageDirectory)/\(folder)"
        if isChannelDownload {
            let downloaded = ChannelDownloadCache.loadDownloadedIDs(channelName: videoInfo.channel)
            if downloaded.contains(videoInfo.id) {
                // 캐시에 있다고 해서 무조건 완료로 치지 않는다.
                // 실제 미디어 파일이 존재해야만 완료 처리한다 (유령 완료 방지).
                if let path = Self.isRealMediaPath(
                    at: "\(channelDir)/\(String(format: "%03d", channelUploadIndex)) - \(videoInfo.title).\(videoInfo.id).mp4"
                ) {
                    return path
                }
            }
            // 캐시에 없어도 실제 미디어 파일이 존재하면 완료 처리한다 (재다운로드 방지).
            // .part/.webp 등 임시·썸네일은 제외.
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: channelDir) else { return nil }
            for file in files where file.contains(videoInfo.id) {
                let path = "\(channelDir)/\(file)"
                if let mediaPath = Self.isRealMediaPath(at: path) { return mediaPath }
            }
            return nil
        }
        let name = formatFilename(template: template)
        let base = (name as NSString).deletingPathExtension
        let extensions: [String] = audioOnly ? ["m4a", "mp3", "aac"] : ["mp4", "m4a", "mkv", "webm"]
        for ext in extensions {
            let path = "\(channelDir)/\(base).\(ext)"
            if let mediaPath = Self.isRealMediaPath(at: path) { return mediaPath }
        }
        // ID 기반 폴백: 제목이 변경되어도 videoId가 포함된 실제 미디어 파일을 찾는다.
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: channelDir) else { return nil }
        for file in files where file.contains(videoInfo.id) {
            let path = "\(channelDir)/\(file)"
            if let mediaPath = Self.isRealMediaPath(at: path) { return mediaPath }
        }
        return nil
    }

    /// 실제 미디어 파일(크기>0, 확장자 유효)이면 path를, 아니면 nil을 반환한다.
    static func isRealMediaPath(at path: String) -> String? {
        guard Self.isRealMediaFile(at: path) else { return nil }
        return path
    }

    static func isRealMediaFile(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0
        else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        return Self.mediaFileExtensions.contains(ext)
    }

    func formatFilename(template: String) -> String {
        let sanitizedTitle = videoInfo.title
            .components(separatedBy: CharacterSet(charactersIn: "/?<>\\:*|\"")
                .union(.newlines))
            .joined()
        let sanitizedChannel = videoInfo.channel
            .components(separatedBy: CharacterSet(charactersIn: "/?<>\\:*|\"")
                .union(.newlines))
            .joined()

        var resolved = template
        if channelUploadIndex == 0, Settings.loadSettings().skipIndexOnFailure {
            resolved = DownloadItem.removeIndexPlaceholder(from: resolved)
        }

        var result = resolved
            .replacingOccurrences(of: "{channel}", with: sanitizedChannel)
            .replacingOccurrences(of: "{title}", with: sanitizedTitle)
            .replacingOccurrences(
                of: "{index}",
                with: String(format: "%03d", channelUploadIndex)
            )
            .replacingOccurrences(
                of: "{date}",
                with: videoInfo.formattedDate
            )
            .replacingOccurrences(
                of: "{resolution}",
                with: selectedFormat.resolutionLabel
            )
        result = result.replacingOccurrences(of: "{id}", with: "")
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
        let ext = audioOnly ? "m4a" : selectedFormat.ext
        result += ".\(videoInfo.id).\(ext)"
        return result
    }

    static func removeIndexPlaceholder(from template: String) -> String {
        let removals: [(String, String)] = [
            (" - {index} - ", " - "),
            (" - {index}", ""),
            ("{index} - ", ""),
            ("_{index}_", "_"),
            ("_{index}", ""),
            ("{index}_", ""),
            (" {index} ", " "),
            (" {index}", ""),
            ("{index} ", ""),
        ]
        var result = template
        for (pattern, replacement) in removals where result.contains(pattern) {
            result = result.replacingOccurrences(of: pattern, with: replacement)
            return result
        }
        return result
    }
}
