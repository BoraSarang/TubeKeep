import SwiftUI

struct AppPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var size: ControlSize = .regular
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, size: ControlSize = .regular, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(size)
    }
}
