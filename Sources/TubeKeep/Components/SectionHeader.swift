import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.sectionHeader)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppMetrics.paddingStandard)
            .padding(.vertical, 6)
    }
}
