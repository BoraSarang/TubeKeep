import SwiftUI

#if DEBUG
struct DebugLogView: View {
    @ObservedObject var manager: DebugLogManager

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(manager.logs.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(size: 9, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.secondary)
                                .id(entry)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .onChange(of: manager.logs.count) { _ in
                        withAnimation {
                            proxy.scrollTo(manager.logs.last ?? "", anchor: .bottom)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(.textBackgroundColor))
            }

            Divider()
            HStack {
                Button("복사") {
                    let text = manager.logs.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .controlSize(.small)

                Button("지우기") {
                    manager.clear()
                }
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
    }
}

extension View {
    func debugLogOverlay(manager: DebugLogManager) -> some View {
        VStack(spacing: 0) {
            self
            DebugLogView(manager: manager)
        }
    }
}
#endif
