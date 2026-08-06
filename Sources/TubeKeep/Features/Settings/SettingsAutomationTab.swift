import SwiftUI
import ComposableArchitecture

struct SettingsAutomationTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "클립보드",
                subtitle: "복사한 YouTube URL을 자동으로 감지합니다"
            )

            SettingsComponents.divider()

            SettingsRow(title: "클립보드 모니터링", description: "YouTube 링크를 복사하면 자동으로 감지해 조회합니다") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.clipboardMonitoring },
                        set: { _ in store.send(.toggleClipboardMonitoring) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.sectionSubHeader()

            SettingsComponents.sectionHeader(
                title: "유휴 자동화",
                subtitle: "Mac을 사용하지 않는 동안 자막과 AI 콘텐츠를 자동으로 생성합니다"
            )

            SettingsComponents.divider()

            idleSubtitleRow

            if UserDefaults.standard.integer(forKey: IdleSubtitleService.settingKey) != 0 {
                SettingsComponents.divider()

                SettingsRow(title: "요약·태그 자동 생성", description: "유휴 자막 다운로드 후 요약과 태그를 자동으로 생성합니다") {
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

                SettingsRow(title: "팟캐스트 자동 생성", description: "요약 생성 후 팟캐스트도 함께 생성합니다 (시간이 다소 걸립니다)") {
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

            SettingsComponents.divider()
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
