import SwiftUI

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.warning)
            Text(message)
                .font(AppFont.cellSubtitle)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
            if let onDismiss {
                Button("✕") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cornerLarge)
                .fill(AppColors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cornerLarge)
                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}