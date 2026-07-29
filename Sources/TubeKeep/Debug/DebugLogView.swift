import SwiftUI

#if DEBUG
struct DebugLogView: View {
    @ObservedObject var manager: DebugLogManager

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(manager.logs) { entry in
                            Text(entry.formatted)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(manager.selectedIds.contains(entry.id) ? .white : textColor(for: entry.level))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(manager.selectedIds.contains(entry.id) ? Color.accentColor : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { handleTap(entry.id) }
                                .id(entry.id)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .onChange(of: manager.logs.count) { _, _ in
                        if manager.autoScroll && !manager.isAutoScrollPaused {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: manager.logs.last?.id) { _, _ in
                        if manager.autoScroll && !manager.isAutoScrollPaused {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.92))
            }

            Divider()
            HStack(spacing: 6) {
                Button {
                    manager.autoScroll.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(manager.autoScroll ? "📌 ON" : "📌 OFF")
                            .font(.caption)
                    }
                }
                .help("자동 스크롤 토글")

                Spacer()

                Button(manager.selectedIds.isEmpty ? "선택 복사" : "\(manager.selectedIds.count)개 복사") {
                    manager.copySelection()
                }
                .disabled(manager.selectedIds.isEmpty)

                Button("선택 해제") {
                    manager.selectedIds.removeAll()
                    manager.lastSelectedId = nil
                }
                .disabled(manager.selectedIds.isEmpty)

                Button("전체 복사") {
                    manager.copyAll()
                }

                Button("로그 비우기") {
                    manager.clear()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
    }

    private func handleTap(_ id: UUID) {
        manager.pauseAutoScroll()
        if NSEvent.modifierFlags.contains(.shift), let last = manager.lastSelectedId {
            guard let currentIdx = manager.logs.firstIndex(where: { $0.id == id }),
                  let lastIdx = manager.logs.firstIndex(where: { $0.id == last }) else { return }
            let range = min(lastIdx, currentIdx)...max(lastIdx, currentIdx)
            for i in range { manager.selectedIds.insert(manager.logs[i].id) }
        } else if NSEvent.modifierFlags.contains(.command) {
            if manager.selectedIds.contains(id) { manager.selectedIds.remove(id) }
            else { manager.selectedIds.insert(id) }
            manager.lastSelectedId = id
        } else {
            manager.selectedIds = [id]
            manager.lastSelectedId = id
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = manager.logs.last else { return }
        withAnimation(.easeOut(duration: 0.1)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func textColor(for level: DebugLogLevel) -> Color {
        switch level {
        case .ERROR: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .WARN: return Color(red: 1.0, green: 0.83, blue: 0.26)
        case .API_REQ: return Color(red: 0.45, green: 0.75, blue: 0.99)
        case .API_RES: return Color(red: 0.55, green: 0.91, blue: 0.60)
        case .SYSTEM: return Color(red: 0.80, green: 0.37, blue: 0.91)
        case .ACTION: return .white
        case .INFO: return .gray
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

    var body: some View {
        DebugLogView(manager: manager)
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
                        manager.autoScroll.toggle()
                    } label: {
                        Image(systemName: manager.autoScroll ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line")
                    }
                    .help(manager.autoScroll ? "자동 스크롤 끄기" : "자동 스크롤 켜기")

                    Button {
                        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "debugLog" }) {
                            window.orderOut(nil)
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
#endif
