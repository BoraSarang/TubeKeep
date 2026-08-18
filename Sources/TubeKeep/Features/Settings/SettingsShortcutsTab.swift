import SwiftUI
import ComposableArchitecture

struct SettingsShortcutsTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var recording: GlobalShortcutAction?
    @State private var keyMonitor: Any?
    @State private var shortcutsVersion = 0

    var body: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "전역 단축키",
                subtitle: "다른 앱에서도 눌러 창을 엽니다"
            )

            SettingsComponents.divider()

            ForEach(GlobalShortcutAction.allCases) { action in
                GlobalShortcutRow(
                    action: action,
                    binding: GlobalShortcutService.shared.binding(for: action),
                    isRecording: recording == action,
                    onRecord: { recording = action },
                    onClear: {
                        GlobalShortcutService.shared.clearBinding(action)
                        shortcutsVersion += 1
                    }
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 3)
            }

            Text("단축키 버튼을 누른 뒤 조합을 입력하세요 (예: ⌘⇧1)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .id(shortcutsVersion)
        .onChange(of: recording) { _, newValue in
            handleRecording(newValue)
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }

    private func handleRecording(_ action: GlobalShortcutAction?) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        guard let action else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !event.isARepeat else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return event }
            let binding = HotKeyBinding(
                keyCode: UInt32(event.keyCode),
                modifiers: GlobalShortcutService.carbonModifiers(from: modifiers)
            )
            GlobalShortcutService.shared.saveBinding(action, binding)
            Task { @MainActor in
                recording = nil
                shortcutsVersion += 1
            }
            return nil
        }
    }
}

// MARK: - Global Shortcut Row

struct GlobalShortcutRow: View {
    let action: GlobalShortcutAction
    let binding: HotKeyBinding?
    let isRecording: Bool
    let onRecord: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(action.rawValue)
                .font(.system(size: 13))
            Spacer()
            if isRecording {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small)
                    Text("키 입력 대기 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 6)
            } else {
                Button(action: onRecord) {
                    Text(binding?.display ?? "설정")
                        .font(.system(size: 11).monospaced())
                        .frame(minWidth: 70)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .help("누를 단축키를 입력하세요")

                if binding != nil {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("단축키 해제")
                }
            }
        }
    }
}