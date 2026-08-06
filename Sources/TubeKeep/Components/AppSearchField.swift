import SwiftUI

struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isSearching: Bool = false
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 14, height: 14)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerStandard))
    }
}
