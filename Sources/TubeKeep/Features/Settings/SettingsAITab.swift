import SwiftUI
import ComposableArchitecture

struct SettingsAITab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            ttsSection

            whisperSection

            SettingsComponents.sectionSubHeader()

            llmSection
        }
    }

    // MARK: - Whisper Section

    private var whisperSection: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "로컬 자막 생성 (Whisper)",
                subtitle: "로컬 동영상 파일의 음성을 인식하여 자동 자막 생성"
            )

            VStack(spacing: 0) {
                SettingsComponents.divider()

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
            SettingsComponents.sectionHeader(
                title: "음성 합성 (TTS)",
                subtitle: "팟캐스트 음성 합성 엔진 선택"
            )

            VStack(spacing: 0) {
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
            }
            .padding(.leading, 20)
        }
    }

    // MARK: - LLM Section

    private var llmSection: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "언어 모델 (LLM)",
                subtitle: "요약/태깅에 사용할 AI 엔진 설정"
            )

            // Google Gemini (1순위)
            VStack(spacing: 0) {
                SettingsComponents.divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Google Gemini")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("유료 · API 키 필요 (1순위. 할당량 초과 시 자동 폴백)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    SettingsComponents.divider()

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

            // OpenRouter (2순위)
            SettingsComponents.sectionSubHeader()

            VStack(spacing: 0) {
                SettingsComponents.divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenRouter")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("무료 · API 키 필요 · openrouter.ai 가입 (2순위 폴백)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    SettingsComponents.divider()

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

                    SettingsComponents.divider()

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

            // yTeaser (3순위)
            SettingsComponents.sectionSubHeader()

            VStack(spacing: 0) {
                SettingsComponents.divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("yTeaser")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("무료 · API 키 불필요 · 50회/일 (3순위 폴백)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                VStack(spacing: 0) {
                    SettingsComponents.divider()

                    SettingsRow(title: "상태") {
                        Text("사용 중")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.leading, 20)
            }
            .padding(.leading, 20)

            // 폴백 순서
            SettingsComponents.sectionSubHeader()

            VStack(spacing: 0) {
                SettingsComponents.divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("폴백 순서")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("요약: Gemini → OpenRouter → yTeaser")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("태깅: Gemini → OpenRouter → 규칙 기반")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }
            .padding(.leading, 20)
        }
    }
}