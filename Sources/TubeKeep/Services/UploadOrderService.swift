import Foundation

actor UploadOrderService {
    private let runner = ProcessRunner()

    func fetchUploadIndex(
        channelId: String,
        targetVideoId: String
    ) async throws -> Int {
        let maxCheck = Settings.loadSettings().maxUploadCheck

        let args = [
            Constants.ytDlpPath,
            "--flat-playlist",
            "--dump-json",
            "--no-download",
            "--no-warnings",
            "--playlist-end", "\(maxCheck)",
            "https://www.youtube.com/channel/\(channelId)/videos?sort=dd",
        ]

        let output: String
        do {
            output = try await runner.runSync(executable: "env", arguments: args)
        } catch {
            return 0
        }

        var videoIds: [String] = []

        for line in output.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String
            else { continue }
            videoIds.append(id)
        }

        // videoIds is newest-first from YouTube's ?sort=dd
        // Reverse position: oldest=1, newest=N
        if let index = videoIds.firstIndex(where: { $0 == targetVideoId }) {
            return videoIds.count - index
        }

        return 0
    }
}
