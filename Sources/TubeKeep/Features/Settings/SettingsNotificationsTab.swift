import SwiftUI
import ComposableArchitecture

struct SettingsNotificationsTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "완료 알림",
                subtitle: "다운로드 완료 시 알려주는 방식을 설정합니다"
            )

            SettingsComponents.divider()

            SettingsRow(title: "알림음", description: "완료 시 알림음 재생") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.playSoundOnComplete },
                        set: { _ in store.send(.togglePlaySound) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "메뉴바 알림", description: "다운로드 완료/실패 등 메뉴바에 알림 표시") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.showMenuBarNotifications },
                        set: { _ in store.send(.toggleShowMenuBarNotifications) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if store.showMenuBarNotifications {
                SettingsRow(title: "알림 지속 시간", description: "메뉴바 알림이 사라질 때까지 시간 (초)") {
                    Stepper(
                        "\(store.menuBarNotificationDuration)초",
                        value: Binding(
                            get: { store.menuBarNotificationDuration },
                            set: { store.send(.setMenuBarNotificationDuration($0)) }
                        ),
                        in: 10...600,
                        step: 10
                    )
                    .controlSize(.small)
                }
            }

            SettingsComponents.divider()
        }
    }
}
