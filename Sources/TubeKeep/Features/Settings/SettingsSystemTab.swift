import SwiftUI
import ComposableArchitecture

struct SettingsSystemTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
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
        }
    }
}