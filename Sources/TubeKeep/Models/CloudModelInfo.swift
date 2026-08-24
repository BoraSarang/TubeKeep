import Foundation

/// 클라우드 LLM 공급자의 모델 목록 항목 — 모델 탭 표시/선택용
struct CloudModelInfo: Equatable, Identifiable {
    let id: String
    let displayName: String
    /// 보조 정보 (NVIDIA 소속 등) — 빈 값이면 미표시
    var subtitle: String = ""
    let contextLength: Int?
    let isFree: Bool

    var displayTitle: String {
        displayName.isEmpty ? id : displayName
    }

    var contextText: String {
        guard let ctx = contextLength, ctx > 0 else { return "" }
        return "\(ctx / 1000)K"
    }
}

/// 공급자별 "사용 중 모델" 저장소 — AIModelTalk modelEnabledOverrides와 동일 개념.
/// ON된 모델들은 배열 순서대로 시도(공급자 내 폴백). 토글 ON 시 끝에 append.
enum CloudModelPrefs {
    private static let migrationKey = "cloudEnabledModelsMigrated"

    static func storageKey(_ kind: CloudProviderKind) -> String {
        "enabledModels.\(kind.rawValue)"
    }

    static func enabled(_ kind: CloudProviderKind) -> [String] {
        guard let data = UserDefaults.standard.data(forKey: storageKey(kind)),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return list
    }

    static func setEnabled(_ kind: CloudProviderKind, _ ids: [String]) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: storageKey(kind))
        }
    }

    static func toggle(_ kind: CloudProviderKind, _ id: String) {
        var current = enabled(kind)
        if let index = current.firstIndex(of: id) {
            current.remove(at: index)
        } else {
            current.append(id)
        }
        setEnabled(kind, current)
    }

    static func isEnabled(_ kind: CloudProviderKind, _ id: String) -> Bool {
        enabled(kind).contains(id)
    }

    /// 기존 단일 선택값(geminiModel 등)을 enabled 배열로 1회 이관
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        let legacyPairs: [(kind: CloudProviderKind, legacyKey: String)] = [
            (.ollama, "ollamaModel"),
            (.gemini, "geminiModel"),
            (.nvidia, "nvidiaModel"),
            (.openRouter, "openRouterModel"),
        ]
        for pair in legacyPairs where enabled(pair.kind).isEmpty {
            let legacy = UserDefaults.standard.string(forKey: pair.legacyKey) ?? ""
            let trimmed = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                setEnabled(pair.kind, [trimmed])
            }
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append("[Settings] 모델 사용 설정 마이그레이션 완료 (기존 단일 선택 → 토글)")
        }
        #endif
    }
}
