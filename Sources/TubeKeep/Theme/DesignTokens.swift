import SwiftUI

// MARK: - 색상 토큰

enum AppColors {

    static let accent = Color.accentColor

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let info = Color.blue

    static let badgeSubtitle = Color.blue
    static let badgeChapters = Color.orange
    static let badgeSummary = Color.green
    static let badgePodcast = Color.purple
    static let badgeResume = Color.accentColor

    static let progressActive = Color.accentColor.opacity(0.12)
    static let progressCompleted = Color.green.opacity(0.10)
    static let progressTrack = Color.primary.opacity(0.1)
    static let selectionRow = Color.accentColor.opacity(0.1)

    static let waveBaseGradient: [Color] = [
        Color.accentColor.opacity(0.28),
        Color.teal.opacity(0.16),
        Color.accentColor.opacity(0.30),
    ]
    static let waveShimmer = Color.white.opacity(0.25)
    static let waveAccentLine = Color.accentColor.opacity(0.5)

    static let overlayBadge = Color.black.opacity(0.75)
    static let cardShadow = Color.black.opacity(0.18)

    // macOS semantic 계열 — 라이트/다크 자동 대응
    static let selectedContentBackground = Color(nsColor: .selectedContentBackgroundColor)
    static let hoverRow = Color.primary.opacity(0.05)
    static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
    static let controlBackground = Color(nsColor: .controlBackgroundColor)
    static let textBackground = Color(nsColor: .textBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
}

// MARK: - 재질 토큰

enum AppMaterial {

    static let regular = Material.regular
    static let thin = Material.thin
    static let ultraThin = Material.ultraThin
    static let bar = Material.bar
}

// MARK: - 폰트 토큰

enum AppFont {

    static let cellTitle = Font.system(.callout, weight: .medium)
    static let cellSubtitle = Font.system(.caption)
    static let meta = Font.system(.caption2)
    static let count = Font.system(.caption)
    static let badge = Font.system(.caption2, weight: .semibold)
    static let badgeIcon = Font.system(.caption2, weight: .bold)
    static let sidebarRow = Font.system(.callout)
    static let sectionHeader = Font.system(.caption, weight: .semibold)
    static let statusBarText = Font.system(.caption2, design: .monospaced)
}

// MARK: - 메트릭 토큰

enum AppMetrics {

    static let paddingSmall: CGFloat = 8
    static let paddingStandard: CGFloat = 12
    static let paddingLarge: CGFloat = 16

    static let cornerSmall: CGFloat = 4
    static let cornerStandard: CGFloat = 6
    static let cornerLarge: CGFloat = 10

    static let badgeStackOffset: CGFloat = 28
    static let capsuleHPadding: CGFloat = 8
    static let capsuleVPadding: CGFloat = 5
    static let capsuleHPaddingSmall: CGFloat = 6
    static let capsuleVPaddingSmall: CGFloat = 4
    static let rowIconSize: CGFloat = 18
}