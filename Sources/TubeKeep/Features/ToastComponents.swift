import SwiftUI

struct ToastMessage: Equatable {
    let id: UUID
    let message: String
    let type: ToastType
}

struct ToastNotification: Equatable {
    let id: UUID
    let message: String
    let type: ToastType
    let timestamp: Date
}

enum ToastType: Equatable {
    case success
    case error
    case info
}

struct ToastBanner: View {
    let toast: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.type == .success
                ? "checkmark.circle.fill"
                : toast.type == .error
                ? "exclamationmark.triangle.fill"
                : "arrow.clockwise"
            )
            .foregroundStyle(toast.type == .success
                ? .green
                : toast.type == .error
                ? .red
                : .blue
            )
            .font(.system(size: 11))

            Text(toast.message)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

struct ToastOverlay: View {
    let toast: ToastMessage
    let videoId: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: toast.type == .success
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
                )
                .font(.system(size: 64))
                .foregroundStyle(toast.type == .success ? .green : .red)

                Text(toast.message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(40)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 6)
        }
        .onTapGesture { onDismiss() }
    }
}
