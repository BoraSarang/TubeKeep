import SwiftUI

struct StatusBadge: View {
    enum Style {
        case capsule
        case inline
    }

    let icon: String
    var text: String? = nil
    var color: Color
    var style: Style = .capsule

    var body: some View {
        switch style {
        case .capsule:
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(AppFont.badgeIcon)
                    .foregroundStyle(.white)
                if let text {
                    Text(text)
                        .font(AppFont.badge)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, AppMetrics.capsuleHPadding)
            .padding(.vertical, AppMetrics.capsuleVPadding)
            .background(Capsule().fill(color))
            .shadow(color: AppColors.cardShadow, radius: 2, x: 0, y: 1)
        case .inline:
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                if let text {
                    Text(text)
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(color)
        }
    }
}
