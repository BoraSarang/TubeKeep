import SwiftUI
import AppKit
import ComposableArchitecture

struct SettingsView: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        HStack(spacing: 0) {
            tabSidebar

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    switch store.selectedTab {
                    case .downloads: downloadsContent
                    case .storage: storageContent
                    case .other: otherContent
                    case .ai: aiContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
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
        }
    }

    // MARK: - Other Tab

    private var otherContent: some View {
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

        }
    }

    // MARK: - AI Tab

    private var aiContent: some View {
        VStack(spacing: 0) {
            ttsSection

            sectionSubHeader

            llmSection
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
