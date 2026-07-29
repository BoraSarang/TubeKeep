import SwiftUI

struct AboutView: View {
    @StateObject private var manager = BundledLibraryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("튜브킵")
                        .font(.title.weight(.semibold))

                    Text("버전 \(appVersion) (build \(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("문의: borasarang@gmail.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("macOS 전용 YouTube 오프라인 라이브러리")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Text("사용한 라이브러리")
                .font(.caption.weight(.semibold))

            ForEach(manager.libraries) { lib in
                LibraryRow(library: lib)
            }

            Divider()
                .padding(.vertical, 4)

            Text("© 2026 BoRaSaRang. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(24)
        .frame(width: 520)
        .task { await manager.refresh() }
    }

    private var icon: NSImage {
        NSApp.applicationIconImage ?? NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil) ?? NSImage()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

struct LibraryRow: View {
    let library: LibraryInfo

    var body: some View {
        HStack(spacing: 4) {
            Text(library.name)
                .foregroundStyle(.primary)
            if let version = library.version {
                Text(version)
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            } else if library.isBundled {
                Text("...")
                    .foregroundStyle(.tertiary)
                    .font(.caption2)
            }
            Spacer()
            Text(library.url)
                .foregroundStyle(.tertiary)
                .truncationMode(.middle)
                .lineLimit(1)
        }
    }
}
