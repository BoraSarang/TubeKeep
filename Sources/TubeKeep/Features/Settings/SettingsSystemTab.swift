import SwiftUI
import ComposableArchitecture

struct SettingsSystemTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var recording: GlobalShortcutAction?
    @State private var keyMonitor: Any?
    @State private var shortcutsVersion = 0

    var body: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "플레이어",
                subtitle: "영상 재생 방식과 화면 표시 옵션을 설정합니다"
            )

            SettingsComponents.divider()

            SettingsRow(title: "비디오 플레이어", description: "영상 재생 방식을 선택합니다") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.playerMode },
                        set: { store.send(.setPlayerMode($0)) }
                    )
                ) {
                    ForEach(PlayerMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }

            SettingsComponents.divider()

            SettingsRow(title: "플레이어 이동 시간", description: "플레이어에서 ← / → 키로 영상을 이동하는 간격 (초)") {
                Stepper(
                    value: Binding(
                        get: { store.seekStepSeconds },
                        set: { store.send(.setSeekStepSeconds($0)) }
                    ),
                    in: 1...60,
                    step: 1
                ) {
                    Text("\(Int(store.seekStepSeconds))초")
                        .font(.callout)
                        .monospacedDigit()
                }
                .fixedSize()
            }

            SettingsComponents.divider()

            SettingsRow(title: "썸네일 미리보기", description: "목록에서 썸네일 미리보기를 표시합니다") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.showThumbnailPreview },
                        set: { _ in store.send(.toggleShowThumbnailPreview) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.sectionSubHeader()

            SettingsComponents.sectionHeader(
                title: "앱 시작",
                subtitle: "TubeKeep을 실행하는 방식을 설정합니다"
            )

            SettingsComponents.divider()

            SettingsRow(title: "시작 시 실행", description: "로그인 시 자동 실행") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { _ in store.send(.toggleLaunchAtLogin) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "메인창 자동 표시", description: "실행 시 메인 창을 자동으로 엽니다") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.showMainWindowOnLaunch },
                        set: { _ in store.send(.toggleShowMainWindowOnLaunch) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            globalShortcutsSection
        }
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

    // MARK: - Global Shortcuts

    private var globalShortcutsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("전역 단축키")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("다른 앱에서도 눌러 창을 엽니다")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)

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
                    ProgressView().controlSize(.mini)
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