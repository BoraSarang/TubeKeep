import SwiftUI

#if DEBUG
struct DebugLogView: View {
    @ObservedObject var manager: DebugLogManager

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(manager.logs.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(size: 9, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.secondary)
                                .id(index)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .onChange(of: manager.logs.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: manager.logs.last) { _, _ in
                        scrollToBottom(proxy: proxy)
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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let lastIndex = manager.logs.count - 1
        guard lastIndex >= 0 else { return }
        withAnimation(.easeOut(duration: 0.1)) {
            proxy.scrollTo(lastIndex, anchor: .bottom)
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
