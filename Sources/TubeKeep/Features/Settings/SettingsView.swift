import SwiftUI
import AppKit
import ComposableArchitecture

struct SettingsView: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var editingPreset: DownloadPreset?

    var body: some View {
        HStack(spacing: 0) {
            tabSidebar

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    switch store.selectedTab {
                    case .downloads: downloadsContent
                    case .storage: storageContent
                    case .notifications: notificationsContent
                    case .system: systemContent
                    case .ai: aiContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorSheet(
                preset: preset,
                onSave: { saved in
                    if preset.name.isEmpty {
                        store.send(.addPreset(saved))
                    } else {
                        store.send(.updatePreset(saved))
                    }
                    editingPreset = nil
                },
                onCancel: {
                    editingPreset = nil
                }
            )
        }
    }

    // MARK: - Tab Sidebar

    private var tabSidebar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .frame(width: 140)
        .padding(.vertical, 12)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let selected = store.selectedTab == tab
        return Button {
            store.send(.setSelectedTab(tab))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Downloads Tab

    private var downloadsContent: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "동시 다운로드", description: "동시에 처리할 다운로드 개수") {
                Stepper(
                    "\(store.concurrentDownloads)개",
                    value: Binding(
                        get: { store.concurrentDownloads },
                        set: { store.send(.setConcurrentDownloads($0)) }
                    ),
                    in: Constants.minConcurrentDownloads...Constants.maxConcurrentDownloads
                )
                .font(.callout)
                .fixedSize()
            }

            divider

            SettingsRow(title: "속도 제한", description: "0 = 무제한") {
                HStack(spacing: 4) {
                    TextField(
                        "0",
                        value: Binding(
                            get: { store.limitRate },
                            set: { store.send(.setLimitRate($0)) }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    Text("MB/s")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }

            divider

            SettingsRow(title: "자동 재시도", description: "실패 시 자동 재시도 횟수") {
                Stepper(
                    "\(store.maxRetries)회",
                    value: Binding(
                        get: { store.maxRetries },
                        set: { store.send(.setMaxRetries($0)) }
                    ),
                    in: 0...10
                )
                .font(.callout)
                .fixedSize()
            }

            divider

            SettingsRow(title: "업로드 확인 개수") {
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
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }

            divider

            SettingsRow(title: "순번 실패 시 생략", description: "실패해도 다음 항목 계속 진행") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.skipIndexOnFailure },
                        set: { _ in store.send(.toggleSkipIndexOnFailure) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            divider

            SettingsRow(title: "기본 해상도", description: "다운로드 기본 해상도") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.defaultResolution },
                        set: { store.send(.setDefaultResolution($0)) }
                    )
                ) {
                    Text("4K").tag(2160)
                    Text("2K").tag(1440)
                    Text("1080p").tag(1080)
                    Text("720p").tag(720)
                    Text("480p").tag(480)
                    Text("360p").tag(360)
                    Text("240p").tag(240)
                    Text("144p").tag(144)
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }

            divider

            SettingsRow(title: "SponsorBlock", description: "다운로드 시 스폰서/인트로/아웃트로 자동 제거") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.sponsorBlock },
                        set: { _ in store.send(.toggleSponsorBlock) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            divider

            SettingsRow(title: "메타데이터 임베딩", description: "파일에 제목/채널/섬네일 정보를 자동으로 포함") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.embedMetadata },
                        set: { _ in store.send(.toggleEmbedMetadata) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            divider

            SettingsRow(title: "자막 언어", description: "자막 다운로드 언어 (override)") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.subtitleLanguageOverride },
                        set: { store.send(.setSubtitleLanguageOverride($0)) }
                    )
                ) {
                    Text("자동 (시스템 언어)").tag("")
                    Text("한국어").tag("ko")
                    Text("영어").tag("en")
                    Text("일본어").tag("ja")
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }

            divider
        }
    }

    // MARK: - Storage Tab

    private var storageContent: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "저장 폴더", description: "다운로드 파일 저장 폴더") {
                Button(store.storageDirectory) {
                    store.send(.selectStorageDirectory)
                }
                .buttonStyle(.plain)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 200, alignment: .trailing)
            }

            divider

            SettingsRow(title: "파일명 템플릿", description: "지원: {channel} {index} {title} {date} {resolution} {id}") {
                TextField(
                    "{channel} - {index} - {title}",
                    text: Binding(
                        get: { store.filenameTemplate },
                        set: { store.send(.setFilenameTemplate($0)) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 200)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }

            divider

            SettingsRow(title: "Smart Mode", description: "URL 입력 시 활성 프리셋으로 바로 다운로드 큐에 추가") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.smartMode },
                        set: { _ in store.send(.toggleSmartMode) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            divider

            SettingsRow(title: "활성 프리셋", description: "Smart Mode에서 사용할 다운로드 프리셋") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.activePresetId },
                        set: { store.send(.setActivePreset($0)) }
                    )
                ) {
                    Text("사용 안 함").tag(nil as UUID?)
                    ForEach(store.presets) { preset in
                        Text(preset.name).tag(preset.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
                .disabled(!store.smartMode)
                .opacity(store.smartMode ? 1 : 0.4)
            }

            if !store.presets.isEmpty {
                divider

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(store.presets.enumerated()), id: \.offset) { _, preset in
                        HStack {
                            Text(preset.name)
                                .font(.callout)
                            Spacer()
                            Text("\(preset.formatType.rawValue) · \(preset.resolution > 0 ? "\(preset.resolution)p" : "오디오")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("편집") {
                                editingPreset = preset
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            Button("삭제") {
                                store.send(.deletePreset(preset.id))
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.leading, 20)
            }

            divider

            Button("프리셋 추가") {
                editingPreset = DownloadPreset(id: UUID(), name: "", formatType: .video, resolution: 1080, includeSubtitles: false, sponsorBlock: false, embedMetadata: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.top, 6)
            .padding(.leading, 20)
        }
    }

    // MARK: - System Tab

    private var systemContent: some View {
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

            divider

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

            divider

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

    // MARK: - Notifications Tab

    private var notificationsContent: some View {
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

            divider

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

            divider

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
        }
    }

    // MARK: - AI Tab

    private var aiContent: some View {
        VStack(spacing: 0) {
            ttsSection

            whisperSection

            sectionSubHeader

            llmSection
        }
    }

    // MARK: - Whisper Section

    private var whisperSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "로컬 자막 생성 (Whisper)",
                subtitle: "로컬 동영상 파일의 음성을 인식하여 자동 자막 생성"
            )

            VStack(spacing: 0) {
                divider

                SettingsRow(title: "Whisper 사용", description: "자막이 없는 동영상에서 Whisper로 자막 생성") {
                    Toggle("", isOn: Binding(
                        get: { store.enableWhisperTranscription },
                        set: { _ in
                            store.send(.toggleWhisperTranscription)
                            store.send(.checkWhisperModelStatus)
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                divider

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
                    divider

                    modelStatusRow
                }
            }
            .padding(.leading, 20)
        }
        .onAppear { store.send(.checkWhisperModelStatus) }
    }

    private var modelStatusRow: some View {
        SettingsRow(title: "모델 상태", description: statusDescription) {
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

    private var statusDescription: String {
        switch store.whisperModelStatus {
        case .unknown: return "확인 중..."
        case .notInstalled: return "모델이 설치되지 않았습니다"
        case .downloading: return "다운로드 중..."
        case .installed: return "모델이 설치되었습니다"
        case .error: return "다운로드 실패: \(store.whisperModelError ?? "알 수 없는 오류")"
        }
    }

    // MARK: - TTS Section

    private var ttsSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "음성 합성 (TTS)",
                subtitle: "팟캐스트 음성 합성 엔진 선택"
            )

            VStack(spacing: 0) {
                divider

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

                divider

                SettingsRow(title: "엔진 정보") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.ttsEngine.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 20)
        }
    }

    // MARK: - LLM Section

    private var llmSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "언어 모델 (LLM)",
                subtitle: "요약/태깅에 사용할 AI 엔진 설정"
            )

            // OpenRouter
            VStack(spacing: 0) {
                divider

                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenRouter")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("무료 · API 키 필요 (openrouter.ai 가입)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    divider

                    SettingsRow(title: "API 키", description: "openrouter.ai 가입 후 발급") {
                        HStack(spacing: 8) {
                            SecureField("sk-or-...", text: Binding(
                                get: { store.openRouterAPIKey },
                                set: { store.send(.setOpenRouterAPIKey($0)) }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(.callout, design: .monospaced))
                            .frame(width: 160)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )

                            Button("무료 가입") {
                                NSWorkspace.shared.open(URL(string: "https://openrouter.ai/settings/keys")!)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        }
                        .fixedSize()
                    }

                    divider

                    SettingsRow(title: "모델", description: "기본: openrouter/free (무료 모델 자동 선택)") {
                        TextField("openrouter/free", text: Binding(
                            get: { store.openRouterModel },
                            set: { store.send(.setOpenRouterModel($0)) }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(.callout, design: .monospaced))
                        .frame(width: 200)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                        .fixedSize()
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.leading, 20)

            // yTeaser
            sectionSubHeader

            VStack(spacing: 0) {
                divider

                VStack(alignment: .leading, spacing: 4) {
                    Text("yTeaser")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("무료 · API 키 불필요 · 50회/일 (IP 기반)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    divider

                    SettingsRow(title: "상태") {
                        Text("사용 중")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.leading, 20)

            // Google Gemini
            sectionSubHeader

            VStack(spacing: 0) {
                divider

                VStack(alignment: .leading, spacing: 4) {
                    Text("Google Gemini")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("유료 · API 키 필요")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    divider

                    SettingsRow(title: "API 키") {
                        HStack(spacing: 8) {
                            SecureField("API 키 입력", text: Binding(
                                get: { store.geminiAPIKey },
                                set: { store.send(.setGeminiAPIKey($0)) }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(.callout, design: .monospaced))
                            .frame(width: 160)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )

                            Button("발급 받기") {
                                NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/app/apikey")!)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        }
                        .fixedSize()
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.leading, 20)

            // 폴백 순서
            sectionSubHeader

            VStack(spacing: 0) {
                divider

                VStack(alignment: .leading, spacing: 4) {
                    Text("폴백 순서")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("요약: OpenRouter → yTeaser → A.X 4.0 → Gemini")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("태깅: OpenRouter → A.X 4.0 → Gemini → 규칙 기반")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }
            .padding(.leading, 20)
        }
    }

    // MARK: - Section Helpers

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private var sectionSubHeader: some View {
        HStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 0.5)
                .padding(.leading, 8)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Components

    private var divider: some View {
        Divider()
            .padding(.leading, 8)
    }

    private var sectionDivider: some View {
        VStack(spacing: 0) {
            Color(nsColor: .separatorColor)
                .frame(height: 1)
            Color(nsColor: .controlBackgroundColor)
                .frame(height: 8)
            Color(nsColor: .separatorColor)
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - SettingsRow

struct SettingsRow<Control: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let control: () -> Control

    init(title: String, description: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.description = description
        self.control = control
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                control()
            }

            if let description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Preset Editor Sheet

struct PresetEditorSheet: View {
    let preset: DownloadPreset
    let onSave: (DownloadPreset) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var formatType: DownloadPreset.PresetFormatType
    @State private var resolution: Int
    @State private var includeSubtitles: Bool

    init(preset: DownloadPreset, onSave: @escaping (DownloadPreset) -> Void, onCancel: @escaping () -> Void) {
        self.preset = preset
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: preset.name)
        _formatType = State(initialValue: preset.formatType)
        _resolution = State(initialValue: preset.resolution)
        _includeSubtitles = State(initialValue: preset.includeSubtitles)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(preset.name.isEmpty ? "새 프리셋" : "프리셋 편집")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("취소") { onCancel() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            VStack(spacing: 0) {
                formRow(title: "이름") {
                    TextField("프리셋 이름", text: $name)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 180)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                }

                Divider().padding(.leading, 8)

                formRow(title: "포맷") {
                    Picker("", selection: $formatType) {
                        ForEach(DownloadPreset.PresetFormatType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .font(.callout)
                }

                Divider().padding(.leading, 8)

                formRow(title: "해상도") {
                    Picker("", selection: $resolution) {
                        Text("4K (2160p)").tag(2160)
                        Text("2K (1440p)").tag(1440)
                        Text("1080p").tag(1080)
                        Text("720p").tag(720)
                        Text("480p").tag(480)
                        Text("360p").tag(360)
                    }
                    .pickerStyle(.menu)
                    .font(.callout)
                    .frame(width: 120)
                    .disabled(formatType == .audio)
                    .opacity(formatType == .audio ? 0.4 : 1)
                }

                Divider().padding(.leading, 8)

                formRow(title: "자막 포함") {
                    Toggle("", isOn: $includeSubtitles)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            HStack {
                Spacer()
                Button("취소") { onCancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)

                Button("저장") {
                    let preset = DownloadPreset(
                        id: preset.id,
                        name: name.trimmingCharacters(in: .whitespaces),
                        formatType: formatType,
                        resolution: formatType == .audio ? 0 : resolution,
                        includeSubtitles: includeSubtitles,
                        sponsorBlock: preset.sponsorBlock,
                        embedMetadata: preset.embedMetadata
                    )
                    onSave(preset)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360)
    }

    private func formRow<Control: View>(title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 60, alignment: .leading)
            Spacer()
            control()
        }
        .padding(.vertical, 10)
    }
}
