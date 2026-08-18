import SwiftUI
import ComposableArchitecture

struct SettingsSystemTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

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
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "보관함 자동 표시", description: "실행 시 보관함을 자동으로 엽니다") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.showLibraryOnLaunch },
                        set: { _ in store.send(.toggleShowLibraryOnLaunch) }
                    )
                )
                .controlSize(.small)
            }

            SettingsComponents.divider()
        }
    }
}