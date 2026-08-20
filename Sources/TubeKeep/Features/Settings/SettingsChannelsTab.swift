import SwiftUI
import ComposableArchitecture

struct SettingsChannelsTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "채널 감시",
                subtitle: "구독 채널과 재생목록의 새 영상을 주기적으로 확인합니다"
            )

            SettingsComponents.divider()

            SettingsRow(title: "새 영상 알림 배지", description: "채널에서 새 영상을 발견하면 메뉴바에 배지를 표시합니다") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.showChannelBadge },
                        set: { _ in store.send(.toggleShowChannelBadge) }
                    )
                )
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "확인 영상 개수", description: "채널당 확인할 최신 영상 수 (100~10000)") {
                HStack(spacing: 4) {
                    TextField(
                        "500",
                        value: Binding(
                            get: { store.maxUploadCheck },
                            set: { store.send(.setMaxUploadCheck($0)) }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    Text("개")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.separator, lineWidth: 0.5)
                )
            }
        }
    }
}
