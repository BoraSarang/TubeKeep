import SwiftUI

#if DEBUG
struct DebugLogView: View {
    @ObservedObject var manager: DebugLogManager
    @Binding var autoScroll: Bool
    @State private var selectedLineIndices: Set<Int> = []
    @State private var lastSelectedIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(manager.logs.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(selectedLineIndices.contains(index) ? .white : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(selectedLineIndices.contains(index) ? Color.accentColor : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTap(at: index)
                                }
                                .id(index)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .onChange(of: manager.logs.count) { _, _ in
                        if autoScroll { scrollToBottom(proxy: proxy) }
                    }
                    .onChange(of: manager.logs.last) { _, _ in
                        if autoScroll { scrollToBottom(proxy: proxy) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.textBackgroundColor))
            }

            Divider()
            HStack(spacing: 6) {
                Spacer()

                Button(selectedLineIndices.isEmpty ? "선택 복사" : "\(selectedLineIndices.count)개의 라인을 복사") {
                    let text = selectedLineIndices.sorted()
                        .compactMap { manager.logs[safe: $0] }
                        .joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .disabled(selectedLineIndices.isEmpty)

                Button("선택 해제") {
                    selectedLineIndices.removeAll()
                    lastSelectedIndex = nil
                }
                .disabled(selectedLineIndices.isEmpty)

                Button("전체 복사") {
                    let text = manager.logs.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }

                Button("로그 비우기") {
                    manager.clear()
                    selectedLineIndices.removeAll()
                    lastSelectedIndex = nil
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
    }

    private func handleTap(at index: Int) {
        if NSEvent.modifierFlags.contains(.shift), let last = lastSelectedIndex {
            let range = min(last, index)...max(last, index)
            selectedLineIndices.formUnion(range)
        } else if NSEvent.modifierFlags.contains(.command) {
            selectedLineIndices.toggle(index)
            lastSelectedIndex = index
        } else {
            selectedLineIndices = [index]
            lastSelectedIndex = index
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

struct DebugLogWindowView: View {
    @StateObject private var manager = DebugLogManager.shared ?? {
        let m = DebugLogManager()
        DebugLogManager.shared = m
        return m
    }()
    @State private var isPinned = false
    @State private var autoScroll = true

    var body: some View {
        DebugLogView(manager: manager, autoScroll: $autoScroll)
            .frame(minWidth: 520, minHeight: 200)
            .alwaysOnTop(isPinned, windowIdentifier: "debugLog")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        isPinned.toggle()
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                    }
                    .help(isPinned ? "최상위 고정 해제" : "항상 최상위로 표시")

                    Button {
                        autoScroll.toggle()
                    } label: {
                        Image(systemName: autoScroll ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line")
                    }
                    .help(autoScroll ? "자동 스크롤 끄기" : "자동 스크롤 켜기")

                    Button {
                        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "debugLog" }) {
                            window.close()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .help("닫기")
                }
            }
    }
}

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) }
        else { insert(element) }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
