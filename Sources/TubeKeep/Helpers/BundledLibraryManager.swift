import Foundation

struct LibraryInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: String
    let isBundled: Bool
    var version: String?
}

@MainActor
final class BundledLibraryManager: ObservableObject {
    static let shared = BundledLibraryManager()
    @Published var libraries: [LibraryInfo] = BundledLibraryManager.predefined

    static let predefined: [LibraryInfo] = [
        LibraryInfo(name: "yt-dlp", url: "https://github.com/yt-dlp/yt-dlp", isBundled: true),
        LibraryInfo(name: "FFmpeg", url: "https://ffmpeg.org", isBundled: true),
        LibraryInfo(name: "FFprobe", url: "https://ffmpeg.org", isBundled: true),
        LibraryInfo(name: "whisper.cpp", url: "https://github.com/ggerganov/whisper.cpp", isBundled: true),
        LibraryInfo(name: "Composable Architecture", url: "https://github.com/pointfreeco/swift-composable-architecture", isBundled: false),
    ]

    private static let cacheKey = "bundledLibraryVersions"
    private var hasWarmedUp = false

    func warmUp() async {
        guard !hasWarmedUp else { return }
        hasWarmedUp = true

        let cached = UserDefaults.standard.dictionary(forKey: Self.cacheKey) as? [String: String] ?? [:]
        var didFetch = false

        for i in libraries.indices where libraries[i].isBundled {
            if let version = cached[libraries[i].name] {
                libraries[i].version = version
            } else {
                libraries[i].version = await Self.fetchVersion(for: libraries[i].name)
                didFetch = true
            }
        }

        if didFetch {
            var dict: [String: String] = [:]
            for lib in libraries {
                guard lib.isBundled, let v = lib.version else { continue }
                dict[lib.name] = v
            }

            UserDefaults.standard.set(dict, forKey: Self.cacheKey)
        }

        Self.preWarmYtDlp()
    }

    func refresh() async {
        if libraries.allSatisfy({ $0.version != nil || !$0.isBundled }) { return }
        hasWarmedUp = false
        await warmUp()
    }

    private static func fetchVersion(for name: String) async -> String? {
        var binaryPath: String
        var args: [String]
        switch name {
        case "yt-dlp":
            binaryPath = Constants.ytDlpPath; args = ["--version"]
        case "FFmpeg":
            binaryPath = Constants.ffmpegPath; args = ["-version"]
        case "FFprobe":
            binaryPath = Constants.ffprobePath; args = ["-version"]
        case "whisper.cpp":
            binaryPath = Constants.whisperPath; args = ["--version"]
        default:
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [binaryPath] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        while process.isRunning {
            try? await Task.sleep(for: .milliseconds(100))
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseVersion(from: output, tool: name)
    }

    private static func parseVersion(from output: String?, tool: String) -> String? {
        guard let output, !output.isEmpty else { return nil }
        switch tool {
        case "yt-dlp":
            return output
        case "FFmpeg", "FFprobe":
            let first = output.components(separatedBy: .newlines).first ?? ""
            let parts = first.components(separatedBy: " ")
            if let idx = parts.firstIndex(of: "version"), idx + 1 < parts.count {
                return parts[idx + 1]
            }
            return parts.dropFirst().first
        case "whisper.cpp":
            return output
        default:
            return nil
        }
    }

    private static func preWarmYtDlp() {
        Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [Constants.ytDlpPath, "--version"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            while process.isRunning {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
