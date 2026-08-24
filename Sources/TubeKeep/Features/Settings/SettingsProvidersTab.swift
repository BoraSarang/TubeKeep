import SwiftUI
import ComposableArchitecture

/// 설정 — 공급자 탭: LLM 공급자(Ollama/Gemini/OpenRouter/yTeaser) 관리
/// API 키 입력은 AIModelTalk ProviderRow 패턴(로컬 @State + 저장 버튼) — 붙여넣기 중복 방지
struct SettingsProvidersTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var ollamaTestRunning = false
    @State private var ollamaTestResult: String?
    @State private var ollamaBaseURLText: String = OllamaService.baseURL

    // API 키 로컬 입력 상태 — 저장 버튼으로만 확정한다
    @State private var geminiKeyInput = ""
    @State private var geminiSaved = false
    @State private var nvidiaKeyInput = ""
    @State private var nvidiaSaved = false
    @State private var openRouterKeyInput = ""
    @State private var openRouterSaved = false

    var body: some View {
        VStack(spacing: 0) {
            localSection
            cloudSection
        }
        .onAppear {
            ollamaBaseURLText = OllamaService.baseURL
            geminiKeyInput = store.geminiAPIKey
            nvidiaKeyInput = store.nvidiaAPIKey
            openRouterKeyInput = store.openRouterAPIKey
            store.send(.refreshOllamaStatus)
        }
    }

    // MARK: - 로컬 AI (Ollama)

    private var localSection: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "로컬 AI",
                subtitle: "API 키 없이 오프라인으로 요약·태깅을 먼저 처리합니다"
            )

            SettingsComponents.divider()

            // 공급자 헤더행 — 상태점 + 이름 + 연결 테스트
            HStack(spacing: 8) {
                Circle()
                    .fill(.teal)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ollama")
                        .font(.system(size: 13, weight: .semibold))
                    Text("로컬 · 설치 필요")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if ollamaTestRunning {
                    ProgressView().controlSize(.small)
                } else if let result = ollamaTestResult {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
                }
                Button("연결 테스트") {
                    Task { await testOllama() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            SettingsComponents.divider()

            // 하위 설정 — 인덴트
            VStack(spacing: 0) {
                SettingsRow(title: "사용", description: "실행 중이면 클라우드보다 먼저 사용") {
                    Toggle("", isOn: Binding(
                        get: { store.ollamaEnabled },
                        set: { _ in
                            store.send(.toggleOllamaEnabled)
                            store.send(.refreshOllamaStatus)
                        }
                    ))
                    .controlSize(.small)
                }

                SettingsComponents.divider()

                SettingsRow(title: "서버 URL", description: "기본: http://localhost:11434") {
                    TextField("http://localhost:11434", text: $ollamaBaseURLText)
                        .textFieldStyle(.plain)
                        .font(.system(.callout, design: .monospaced))
                        .frame(width: 200)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.controlBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppColors.separator, lineWidth: 0.5)
                        )
                        .fixedSize()
                        .onSubmit { saveBaseURL() }
                }

                SettingsComponents.divider()

                SettingsRow(title: "서버 상태", description: ollamaStatusDescription) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(store.ollamaServerRunning ? .green : .gray)
                            .frame(width: 8, height: 8)

                        Button("새로고침") {
                            store.send(.refreshOllamaStatus)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .fixedSize()
                }
            }
            .padding(.leading, 20)
        }
    }

    // MARK: - 클라우드

    private var cloudSection: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "클라우드",
                subtitle: "Ollama 실패 또는 미사용 시 폴백 순서대로 동작합니다"
            )

            SettingsComponents.divider()

            // Gemini
            HStack(spacing: 8) {
                Circle()
                    .fill(.purple)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gemini")
                        .font(.system(size: 13, weight: .semibold))
                    Text("멀티모달 · API 키 필요")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SecureField("API 키 입력", text: $geminiKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .frame(width: 160)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.controlBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.separator, lineWidth: 0.5))

                Button(geminiSaved ? "✓ 저장됨" : "저장") {
                    store.send(.setGeminiAPIKey(geminiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)))
                    geminiSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { geminiSaved = false }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(geminiKeyInput.isEmpty)

                Button("발급 받기") {
                    NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/app/apikey")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            SettingsComponents.divider()

            // NVIDIA NIM
            HStack(spacing: 8) {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NVIDIA NIM")
                        .font(.system(size: 13, weight: .semibold))
                    Text("무료 티어 · API 키 필요")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SecureField("nvapi-...", text: $nvidiaKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .frame(width: 160)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.controlBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.separator, lineWidth: 0.5))

                Button(nvidiaSaved ? "✓ 저장됨" : "저장") {
                    store.send(.setNVIDIAAPIKey(nvidiaKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)))
                    nvidiaSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { nvidiaSaved = false }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(nvidiaKeyInput.isEmpty)

                Button("발급 받기") {
                    NSWorkspace.shared.open(URL(string: "https://build.nvidia.com/settings/api-keys")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            SettingsComponents.divider()

            // OpenRouter
            HStack(spacing: 8) {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenRouter")
                        .font(.system(size: 13, weight: .semibold))
                    Text("무료 모델 최다 · API 키 필요")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SecureField("sk-or-...", text: $openRouterKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .frame(width: 160)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.controlBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.separator, lineWidth: 0.5))

                Button(openRouterSaved ? "✓ 저장됨" : "저장") {
                    store.send(.setOpenRouterAPIKey(openRouterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)))
                    openRouterSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { openRouterSaved = false }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(openRouterKeyInput.isEmpty)

                Button("무료 가입") {
                    NSWorkspace.shared.open(URL(string: "https://openrouter.ai/settings/keys")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            SettingsComponents.divider()

            // yTeaser
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("yTeaser")
                        .font(.system(size: 13, weight: .semibold))
                    Text("무료 · API 키 불필요 · 50회/일")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("사용 중")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Actions

    private func saveBaseURL() {
        var url = ollamaBaseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        ollamaBaseURLText = url
        UserDefaults.standard.set(url, forKey: "ollamaBaseURL")
        OllamaService.invalidateServerCache()
        store.send(.refreshOllamaStatus)
    }

    private func testOllama() async {
        ollamaTestRunning = true
        ollamaTestResult = nil
        defer { ollamaTestRunning = false }

        guard await OllamaService.isServerRunning() else {
            ollamaTestResult = "✗ 연결 실패 — ollama serve 확인"
            return
        }

        let models = await OllamaService.listModels()
        if models.isEmpty {
            ollamaTestResult = "✓ 연결 성공 (모델 0개)"
        } else {
            ollamaTestResult = "✓ 연결 성공 (모델 \(models.count)개)"
        }
        store.send(.refreshOllamaStatus)
    }

    private var ollamaStatusDescription: String {
        if !store.ollamaEnabled { return "비활성화됨" }
        return store.ollamaServerRunning ? "localhost:11434 연결됨" : "서버 꺼짐 — 클라우드 체인 사용"
    }
}
