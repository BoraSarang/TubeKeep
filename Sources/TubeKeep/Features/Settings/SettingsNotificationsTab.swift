import SwiftUI
import ComposableArchitecture

struct SettingsNotificationsTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
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

            SettingsRow(title: "채널 업데이트 확인", description: "30분마다 채널의 새 영상 확인") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.showChannelBadge },
                        set: { _ in store.send(.toggleShowChannelBadge) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            idleSubtitleRow

            if UserDefaults.standard.integer(forKey: IdleSubtitleService.settingKey) != 0 {
                SettingsComponents.divider()

                SettingsRow(title: "유휴 시 요약·태그 자동 생성", description: "유휴 자막 다운로드 후 요약과 태그를 자동으로 생성합니다") {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.idleAutoSummary },
                            set: { _ in store.send(.toggleIdleAutoSummary) }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                SettingsRow(title: "유휴 시 팟캐스트 자동 생성", description: "요약 생성 후 팟캐스트도 함께 생성합니다 (시간이 다소 걸립니다)") {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.idleAutoPodcast },
                            set: { _ in store.send(.toggleIdleAutoPodcast) }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    private var idleSubtitleRow: some View {
        SettingsRow(title: "유휴 시 자막 자동 다운로드", description: "Mac을 N분 이상 사용하지 않으면 자막 없는 최근 영상부터 순차 다운로드합니다. 사용을 시작하면 멈춥니다") {
            Picker("", selection: Binding(
                get: { UserDefaults.standard.integer(forKey: IdleSubtitleService.settingKey) },
                set: { UserDefaults.standard.set($0, forKey: IdleSubtitleService.settingKey) }
            )) {
                Text("끄기").tag(0)
                Text("5분").tag(5)
                Text("10분").tag(10)
                Text("30분").tag(30)
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }
}