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
        let template = UserDefaults.standard.string(
            forKey: Constants.settingsSaveKey
        ).flatMap { try? JSONDecoder().decode(Settings.self, from: Data($0.utf8)) }
            .map { $0.filenameTemplate } ?? Constants.defaultFilenameTemplate
        return "\(Constants.channelStorageDirectory)/\(folder)/\(formatFilename(template: template))"
    }

    func checkExistingFile(storageDirectory: String, template: String) -> String? {
        BookmarkManager.ensureAccess()
        let folder = Constants.sanitizeFolderName(videoInfo.channel)
        let channelDir = "\(storageDirectory)/\(folder)"
        if isChannelDownload {
            let downloaded = ChannelDownloadCache.loadDownloadedIDs(channelName: videoInfo.channel)
            guard downloaded.contains(videoInfo.id) else { return nil }
            return "\(channelDir)/\(String(format: "%03d", channelUploadIndex)) - \(videoInfo.title).\(videoInfo.id).mp4"
        }
        let name = formatFilename(template: template)
        let base = (name as NSString).deletingPathExtension
        let extensions: [String] = audioOnly ? ["m4a", "mp3", "aac"] : ["mp4", "m4a", "mkv", "webm"]
        for ext in extensions {
            let path = "\(channelDir)/\(base).\(ext)"
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
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
        if channelUploadIndex == 0 {
            if let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
               let data = json.data(using: .utf8),
               let s = try? JSONDecoder().decode(Settings.self, from: data),
               s.skipIndexOnFailure {
                resolved = DownloadItem.removeIndexPlaceholder(from: resolved)
            }
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
