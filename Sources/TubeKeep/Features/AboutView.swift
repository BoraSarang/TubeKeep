import SwiftUI

struct AboutView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                Text("튜브킵 (TubeKeep)")
                    .font(.title.weight(.semibold))

                Text("버전 \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("macOS 전용 YouTube 오프라인 라이브러리")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical, 4)

                Text("사용한 라이브러리")
                    .font(.caption.weight(.semibold))
                creditRow("yt-dlp", "https://github.com/yt-dlp/yt-dlp")
                creditRow("FFmpeg", "https://ffmpeg.org")
                creditRow("Composable Architecture", "https://github.com/pointfreeco/swift-composable-architecture")

                Divider()
                    .padding(.vertical, 4)

                Text("© 2025 BoRaSaRang. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("EMail: borasarang@gmail.com")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(24)
        .frame(width: 440)
    }

    private var icon: NSImage {
        NSApp.applicationIconImage ?? NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil) ?? NSImage()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func creditRow(_ name: String, _ url: String) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .foregroundStyle(.primary)
            Text(url)
                .foregroundStyle(.tertiary)
                .truncationMode(.middle)
                .lineLimit(1)
        }
    }
}
