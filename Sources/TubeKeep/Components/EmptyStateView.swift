import SwiftUI

struct EmptyStateView<Actions: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let actions: () -> Actions

    init(icon: String, title: String, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions()
        }
    }
}
