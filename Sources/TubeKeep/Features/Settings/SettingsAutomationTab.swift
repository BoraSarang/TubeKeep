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
                title: "음성 합성 (TTS)",
                subtitle: "팟캐스트 음성 합성 엔진 선택"
            )

            SettingsComponents.divider()

            SettingsRow(title: "엔진 선택", description: "팟캐스트 생성 시 사용할 TTS 엔진") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.ttsEngine },
                        set: { store.send(.setTTSEngine($0)) }
                    )
                ) {
                    ForEach(TTSEngine.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }

            SettingsComponents.divider()

            SettingsRow(title: "엔진 정보") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.ttsEngine.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsComponents.sectionHeader(
                title: "로컬 자막 생성 (Whisper)",
                subtitle: "로컬 동영상 파일의 음성을 인식하여 자동 자막 생성"
            )

            SettingsComponents.divider()

            SettingsRow(title: "Whisper 사용", description: "자막이 없는 동영상에서 Whisper로 자막 생성") {
                Toggle("", isOn: Binding(
                    get: { store.enableWhisperTranscription },
                    set: { _ in
                        store.send(.toggleWhisperTranscription)
                        store.send(.checkWhisperModelStatus)
                    }
                ))
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "모델 크기", description: "큰 모델일수록 정확도↑ 속도↓") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.whisperModelSize },
                        set: { store.send(.setWhisperModelSize($0)) }
                    )
                ) {
                    Text("Tiny (~75 MB)").tag("tiny")
                    Text("Base (~142 MB)").tag("base")
                    Text("Small (~466 MB)").tag("small")
                    Text("Medium (~1.5 GB)").tag("medium")
                    Text("Large (~2.9 GB)").tag("large")
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }
            .opacity(store.enableWhisperTranscription ? 1 : 0.4)
            .disabled(!store.enableWhisperTranscription)

            if store.enableWhisperTranscription {
                SettingsComponents.divider()

                whisperModelStatusRow
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
            if store.enableWhisperTranscription {
                store.send(.checkWhisperModelStatus)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ActivityLogStore.activityLogDidChangeNotification)) { _ in
            refreshLogs()
        }
    }

    private func refreshLogs() {
        activityLogs = ActivityLogStore.shared.loadRecent(limit: 500)
    }

    private var whisperModelStatusRow: some View {
        SettingsRow(title: "모델 상태", description: whisperStatusDescription) {
            HStack(spacing: 8) {
                switch store.whisperModelStatus {
                case .unknown, .notInstalled:
                    Button("모델 다운로드") {
                        store.send(.downloadWhisperModel)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                case .downloading:
                    HStack(spacing: 8) {
                        ProgressView(value: store.whisperModelProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                        Text("\(Int(store.whisperModelProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("취소") {
                            store.send(.cancelWhisperModelDownload)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .controlSize(.small)
                    }

                case .installed:
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                        Text("설치됨")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("재설치") {
                            store.send(.downloadWhisperModel)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .controlSize(.small)
                    }

                case .error:
                    Button("다시 시도") {
                        store.send(.downloadWhisperModel)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    private var whisperStatusDescription: String {
        switch store.whisperModelStatus {
        case .unknown: return "확인 중..."
        case .notInstalled: return "모델이 설치되지 않았습니다"
        case .downloading: return "다운로드 중..."
        case .installed: return "모델이 설치되었습니다"
        case .error: return "다운로드 실패: \(store.whisperModelError ?? "알 수 없는 오류")"
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
