import SwiftUI
import ComposableArchitecture

/// 설정 — 모델 탭: 4개 공급자 모델 관리.
/// AIModelTalk과 동일한 "사용함/사용안함" 토글 — 켠 모델들은 순서대로 시도(공급자 내 폴백).
struct SettingsModelsTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    @State private var selectedProvider: CloudProviderKind = .ollama
    @State private var newModelName = ""
    @State private var pendingDeleteModel: String?

    private let recommendedModels = [
        "qwen2.5:14b", "qwen2.5:7b", "qwen2.5:3b",
        "llama3.2", "gemma2:9b", "mistral:7b",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedProvider) {
                ForEach(CloudProviderKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 420)
            .padding(.horizontal, 12)
            .padding(.top, 10)

            switch selectedProvider {
            case .ollama:
                ollamaSection
            case .gemini:
                cloudSection(.gemini)
            case .nvidia:
                cloudSection(.nvidia)
            case .openRouter:
                cloudSection(.openRouter)
            }
        }
        .onAppear {
            store.send(.loadEnabledModels)
            store.send(.refreshOllamaStatus)
            if store.openRouterModels.isEmpty {
                store.send(.fetchCloudModels(.openRouter))
            }
        }
    }

    // MARK: - 검색 필드 + 개수

    private func searchField(totalCount: Int, shownCount: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("모델 검색", text: Binding(
                get: { store.modelSearchText },
                set: { store.send(.setModelSearchText($0)) }
            ))
            .textFieldStyle(.plain)

            if !store.modelSearchText.isEmpty {
                Button {
                    store.send(.setModelSearchText(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if isLoading {
                ProgressView().controlSize(.small)
            }

            // 개수 배지 — 필터 중이면 "표시/전체"
            if shownCount == totalCount {
                Text("\(totalCount)개")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("\(shownCount) / \(totalCount)개")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.modelSearchText.isEmpty ? .green : .secondary)
                    .monospacedDigit()
            }

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help("모델 목록 새로고침")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .quaternaryLabelColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var isLoading: Bool {
        switch selectedProvider {
        case .ollama: return false
        case .gemini: return store.geminiModelsLoading
        case .nvidia: return store.nvidiaModelsLoading
        case .openRouter: return store.openRouterModelsLoading
        }
    }

    private func refresh() {
        switch selectedProvider {
        case .ollama:
            store.send(.refreshOllamaStatus)
        case .gemini, .nvidia, .openRouter:
            store.send(.fetchCloudModels(selectedProvider))
        }
    }

    private func enabledSet(_ kind: CloudProviderKind) -> Set<String> {
        switch kind {
        case .ollama: return store.ollamaEnabledModels
        case .gemini: return store.geminiEnabledModels
        case .nvidia: return store.nvidiaEnabledModels
        case .openRouter: return store.openRouterEnabledModels
        }
    }

    // MARK: - 클라우드 공급자 공통 (Gemini/NVIDIA/OpenRouter)

    private func cloudSection(_ kind: CloudProviderKind) -> some View {
        VStack(spacing: 0) {
            let all = filteredCloudModels(kind)
            searchField(
                totalCount: totalCount(kind),
                shownCount: all.count
            )

            if kind == .openRouter {
                freeOnlyToggle(shownCount: all.count)
            }

            SettingsComponents.divider()

            let selectedIDs = enabledSet(kind)

            if all.isEmpty && !isLoading {
                emptyState(kind)
            } else {
                VStack(spacing: 0) {
                    ForEach(all) { model in
                        cloudModelRow(model: model, isEnabled: selectedIDs.contains(model.id), kind: kind)
                        SettingsComponents.divider().opacity(0.4)
                    }
                }
            }

            if let error = store.cloudModelError {
                SettingsComponents.divider()
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            Spacer(minLength: 0)
        }
    }

    private func totalCount(_ kind: CloudProviderKind) -> Int {
        switch kind {
        case .ollama: return store.ollamaModels.count
        case .gemini: return store.geminiModels.count
        case .nvidia: return store.nvidiaModels.count
        case .openRouter:
            return store.openRouterFreeOnly ? store.openRouterModels.filter(\.isFree).count : store.openRouterModels.count
        }
    }

    private func freeOnlyToggle(shownCount: Int) -> some View {
        Toggle("무료만 보기", isOn: Binding(
            get: { store.openRouterFreeOnly },
            set: { _ in store.send(.toggleOpenRouterFreeOnly) }
        ))
        .toggleStyle(.checkbox)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func filteredCloudModels(_ kind: CloudProviderKind) -> [CloudModelInfo] {
        let all: [CloudModelInfo]
        switch kind {
        case .gemini: all = store.geminiModels
        case .nvidia: all = store.nvidiaModels
        case .openRouter:
            all = store.openRouterFreeOnly ? store.openRouterModels.filter(\.isFree) : store.openRouterModels
        case .ollama: all = []
        }

        let query = store.modelSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.id.lowercased().contains(query) || $0.displayName.lowercased().contains(query)
        }
    }

    private func emptyState(_ kind: CloudProviderKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch kind {
            case .gemini where store.geminiAPIKey.isEmpty:
                Text("공급자 탭에서 Gemini API 키를 먼저 입력해 주세요")
            case .nvidia where store.nvidiaAPIKey.isEmpty:
                Text("공급자 탭에서 NVIDIA API 키를 먼저 입력해 주세요")
            default:
                Text(isLoading ? "모델 목록 조회 중..." : "모델이 없습니다 — ↻로 새로고침하세요")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    /// 사용 토글 행 — AIModelTalk ModelRow 패턴
    @ViewBuilder
    private func cloudModelRow(model: CloudModelInfo, isEnabled: Bool, kind: CloudProviderKind) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.displayTitle)
                    .font(.system(size: 13, weight: isEnabled ? .semibold : .regular))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                Text(model.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !model.subtitle.isEmpty {
                Text(model.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            if model.isFree {
                Text("무료")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
            }
            if !model.contextText.isEmpty {
                Text(model.contextText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in store.send(.toggleCloudModel(kind, model.id)) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .help(isEnabled ? "사용 중 — 실패 시 다음 사용 모델로 넘어감" : "끔 — 체인에서 제외")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Ollama 모델 (설치/삭제 포함)

    private var ollamaSection: some View {
        VStack(spacing: 0) {
            SettingsComponents.divider()

            if !store.ollamaServerRunning {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ollama 서버에 연결할 수 없습니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("터미널에서 'ollama serve'를 실행하거나 공급자 탭에서 연결을 확인하세요.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)

                SettingsComponents.divider()
                installArea
            } else if store.ollamaModels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("설치된 모델이 없습니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("아래에서 모델을 설치하세요.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)

                SettingsComponents.divider()
                installArea
            } else {
                let query = store.modelSearchText.trimmingCharacters(in: .whitespaces).lowercased()
                let filtered = query.isEmpty ? store.ollamaModels : store.ollamaModels.filter { $0.lowercased().contains(query) }

                searchField(totalCount: store.ollamaModels.count, shownCount: filtered.count)

                if filtered.isEmpty {
                    Text("'\(store.modelSearchText)'에 일치하는 모델이 없습니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(filtered, id: \.self) { modelName in
                            ollamaModelRow(modelName)
                            SettingsComponents.divider().opacity(0.4)
                        }
                    }
                }
                installArea
            }

            if let error = store.ollamaPullError {
                SettingsComponents.divider()
                Text("설치 실패: \(error)")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .alert(
            "모델 삭제",
            isPresented: Binding(
                get: { pendingDeleteModel != nil },
                set: { if !$0 { pendingDeleteModel = nil } }
            )
        ) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                if let name = pendingDeleteModel {
                    store.send(.deleteOllamaModel(name))
                }
                pendingDeleteModel = nil
            }
        } message: {
            if let name = pendingDeleteModel {
                Text("'\(name)' 모델을 삭제하시겠습니까?")
            }
        }
    }

    @ViewBuilder
    private func ollamaModelRow(_ modelName: String) -> some View {
        let isEnabled = store.ollamaEnabledModels.contains(modelName)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(modelName)
                    .font(.system(size: 13, weight: isEnabled ? .semibold : .regular))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }

            Spacer()

            if store.ollamaInstallingModel == modelName,
               let progress = store.ollamaPullProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 90)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                pendingDeleteModel = modelName
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(store.ollamaPullProgress == nil ? Color.red.opacity(0.8) : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(store.ollamaPullProgress != nil)
            .help("삭제")

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in store.send(.toggleCloudModel(.ollama, modelName)) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .help(isEnabled ? "사용 중 — 실패 시 다음 사용 모델로 넘어감" : "끔 — 체인에서 제외")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var installArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("모델 설치")
                .font(.system(size: 13, weight: .medium))

            HStack {
                TextField("예: qwen2.5:14b", text: $newModelName)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.controlBackground))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.separator, lineWidth: 0.5))

                if store.ollamaPullProgress != nil {
                    ProgressView(value: store.ollamaPullProgress ?? 0)
                        .progressViewStyle(.linear)
                        .frame(width: 110)
                    Text("\(Int((store.ollamaPullProgress ?? 0) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Button("설치") {
                        let trimmed = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.send(.installOllamaModel(trimmed))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.ollamaEnabled || !store.ollamaServerRunning)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("추천 무료 모델 (한국어 요약·태깅 적합)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recommendedModels, id: \.self) { model in
                            Button(model) {
                                newModelName = model
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.ollamaModels.contains(model))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}
