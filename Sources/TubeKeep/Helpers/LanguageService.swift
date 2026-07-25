import Foundation

enum LanguageService {
    private static func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append("[LanguageService] \(message)")
        }
        #endif
    }

    /// 시스템 언어 코드 (예: "ko", "en", "ja")
    static var systemLanguageCode: String {
        let code = String(Locale.preferredLanguages.first?.prefix(2) ?? "en")
        log("systemLanguageCode → \(code)")
        return code
    }

    /// 설정 override 값 (빈 문자열이면 시스템 언어 따름)
    static var subtitleLanguageOverride: String {
        let overrides: [String: String] = [
            "ko": "ko,en",
            "en": "en",
            "ja": "ja,en",
        ]
        guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
              let data = json.data(using: .utf8),
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              !settings.subtitleLanguageOverride.isEmpty
        else { return "" }
        let result = overrides[settings.subtitleLanguageOverride] ?? ""
        log("subtitleLanguageOverride → \(result.isEmpty ? "없음" : result)")
        return result
    }

    /// 자막 다운로드 언어 리스트 (override → 시스템 언어 fallback)
    static var subtitleLanguages: String {
        let override = subtitleLanguageOverride
        if !override.isEmpty {
            log("subtitleLanguages → \(override) (override)")
            return override
        }
        let lang = systemLanguageCode
        let result: String
        switch lang {
        case "ko": result = "ko,en"
        case "ja": result = "ja,en"
        default:   result = "en"
        }
        log("subtitleLanguages → \(result) (system: \(lang))")
        return result
    }

    /// Apple TTS 언어 코드
    static var appleTTSLanguage: String {
        let lang = systemLanguageCode
        let result: String
        switch lang {
        case "ko": result = "ko-KR"
        case "ja": result = "ja-JP"
        default:   result = "en-US"
        }
        log("appleTTSLanguage → \(result) (system: \(lang))")
        return result
    }

    /// Edge TTS 음성 맵핑
    static func ttsVoice(for engine: TTSEngine, gender: TTSEngine.Gender) -> String {
        if engine == .apple {
            let v = appleVoice(gender)
            log("ttsVoice(apple, \(gender)) → \(v)")
            return v
        }
        let map: [String: (male: String, female: String)] = [
            "ko": ("ko-KR-InJoonNeural", "ko-KR-SunHiNeural"),
            "en": ("en-US-ChristopherNeural", "en-US-JennyNeural"),
            "ja": ("ja-JP-KeitaNeural", "ja-JP-NanamiNeural"),
            "zh": ("zh-CN-YunxiNeural", "zh-CN-XiaoxiaoNeural"),
            "es": ("es-ES-AlvaroNeural", "es-ES-ElviraNeural"),
            "fr": ("fr-FR-HenriNeural", "fr-FR-DeniseNeural"),
            "de": ("de-DE-ConradNeural", "de-DE-KatjaNeural"),
        ]
        let pair = map[systemLanguageCode] ?? ("ko-KR-InJoonNeural", "ko-KR-SunHiNeural")
        let v = gender == .male ? pair.male : pair.female
        log("ttsVoice(edge, \(gender)) → \(v)")
        return v
    }

    /// Apple TTS 음성 식별자
    static func appleVoice(_ gender: TTSEngine.Gender) -> String {
        let map: [String: (male: String, female: String)] = [
            "ko": ("com.apple.eloquence.ko-KR.Reed", "com.apple.voice.super-compact.ko-KR.Yuna"),
            "en": ("com.apple.voice.compact.en-US.Rocko", "com.apple.voice.compact.en-US.Samantha"),
            "ja": ("com.apple.voice.compact.ja-JP.Hattori", "com.apple.voice.compact.ja-JP.Kyoko"),
        ]
        let pair = map[systemLanguageCode] ?? map["ko"]!
        let v = gender == .male ? pair.male : pair.female
        log("appleVoice(\(gender)) → \(v)")
        return v
    }

    /// AI 프롬프트에 주입할 언어 지시문
    static var aiPromptLanguage: String {
        let lang = systemLanguageCode
        let result: String
        switch lang {
        case "ko": result = "한국어로 응답해주세요."
        case "ja": result = "日本語で答えてください。"
        default:   result = "Answer in English."
        }
        log("aiPromptLanguage → \(result) (system: \(lang))")
        return result
    }
}

extension LanguageService {
    /// 브라우저 쿠키 args (설정에서 활성화된 경우)
    static var cookiesArgs: [String] {
        guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
              let data = json.data(using: .utf8),
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              !settings.cookiesFromBrowser.isEmpty
        else { return [] }
        let result = ["--cookies-from-browser", settings.cookiesFromBrowser]
        log("cookiesArgs → \(result.joined(separator: " "))")
        return result
    }
}

extension TTSEngine {
    enum Gender { case male, female }
}
