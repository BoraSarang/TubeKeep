import SwiftUI

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
            if let onDismiss {
                Button("✕") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cornerLarge)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cornerLarge)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}
