import SwiftUI
import ComposableArchitecture

struct SettingsAutomationTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var activityLogs: [String] = []

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
                .controlSize(.small)
            }

            SettingsComponents.sectionHeader(
                title: "유휴 자동화",
                subtitle: "Mac을 사용하지 않는 동안 자막과 AI 콘텐츠를 자동으로 생성합니다"
            )

            SettingsComponents.divider()

            idleSubtitleRow

            if UserDefaults.standard.integer(forKey: IdleSubtitleService.settingKey) != 0 {
                SettingsComponents.divider()

                idleSubtitleModeRow

                SettingsComponents.divider()

                idleSubtitleSortRow

                SettingsComponents.divider()

                SettingsRow(title: "요약·태그 자동 생성", description: "유휴 자막 다운로드 후 요약과 태그를 자동으로 생성합니다") {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.idleAutoSummary },
                            set: { _ in store.send(.toggleIdleAutoSummary) }
                        )
                    )
                    .controlSize(.small)
                }

                SettingsComponents.divider()

                SettingsRow(title: "팟캐스트 자동 생성", description: "요약 생성 후 팟캐스트도 함께 생성합니다 (시간이 다소 걸립니다)") {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.idleAutoPodcast },
                            set: { _ in store.send(.toggleIdleAutoPodcast) }
                        )
                    )
                    .controlSize(.small)
                }
            }

            SettingsComponents.sectionHeader(
                title: "행동 로그",
                subtitle: "유휴 자동화가 실행한 작업을 순서대로 기록합니다"
            )

            SettingsComponents.divider()

            HStack {
                Text(activityLogs.isEmpty ? "아직 기록이 없습니다" : "최근 \(activityLogs.count)건")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("로그 지우기") {
                    ActivityLogStore.shared.clear()
                }
                .font(.system(size: 11))
                .disabled(activityLogs.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !activityLogs.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(activityLogs.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(line.prefix(19)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 130, alignment: .leading)
                                Text(String(line.dropFirst(21)))
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                            Divider()
                                .opacity(0.4)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .onAppear {
            refreshLogs()
        }
        .onReceive(NotificationCenter.default.publisher(for: ActivityLogStore.activityLogDidChangeNotification)) { _ in
            refreshLogs()
        }
    }

    private func refreshLogs() {
        activityLogs = ActivityLogStore.shared.loadRecent(limit: 500)
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

    private var idleSubtitleModeRow: some View {
        SettingsRow(title: "유휴 자막 방식", description: "정식 자막이 없으면 선택한 방식으로 자막을 만듭니다. 자동은 정식 다운로드 후 없으면 Whisper로 생성합니다") {
            Picker("", selection: Binding(
                get: { store.idleSubtitleMode },
                set: { store.send(.setIdleSubtitleMode($0)) }
            )) {
                Text("자동").tag("auto")
                Text("다운로드만").tag("download")
                Text("Whisper로 생성").tag("whisper")
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }

    private var idleSubtitleSortRow: some View {
        SettingsRow(title: "자막 처리 순서", description: "보관함에서 자막 없는 영상을 어떤 순서로 처리할지 선택합니다") {
            Picker("", selection: Binding(
                get: { store.idleSubtitleSort },
                set: { store.send(.setIdleSubtitleSort($0)) }
            )) {
                Text("최근 다운로드순").tag("recent")
                Text("업로드 최신순").tag("upload")
                Text("오래된 다운로드순").tag("oldest")
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }
}
