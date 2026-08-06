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

    static let progressActive = Color.blue.opacity(0.08)
    static let progressCompleted = Color.green.opacity(0.06)
    static let progressTrack = Color.black.opacity(0.4)
    static let selectionRow = Color.accentColor.opacity(0.1)

    static let waveBaseGradient: [Color] = [
        Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.35),
        Color(red: 0.0, green: 0.6, blue: 0.8).opacity(0.25),
        Color(red: 0.2, green: 0.3, blue: 0.8).opacity(0.35),
    ]
    static let waveShimmer = Color.white.opacity(0.2)
    static let waveAccentLine = Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.5)

    static let overlayBadge = Color.black.opacity(0.75)
    static let cardShadow = Color.black.opacity(0.2)
}

// MARK: - 폰트 토큰

enum AppFont {

    static let cellTitle = Font.system(size: 12, weight: .medium)
    static let cellSubtitle = Font.system(size: 11)
    static let meta = Font.system(size: 10)
    static let count = Font.system(size: 11)
    static let badge = Font.system(size: 10, weight: .semibold)
    static let badgeIcon = Font.system(size: 10, weight: .bold)
    static let sidebarRow = Font.system(size: 12)
    static let sectionHeader = Font.system(size: 11, weight: .semibold)
    static let statusBarText = Font.system(size: 10, design: .monospaced)
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
