import Foundation

/// AI 요약/태깅 등에 사용하는 프롬프트를 한 곳에서 관리한다.
enum LLMPrompts {

    /// YouTube 영상 요약 프롬프트 — Gemini/OpenRouter 공통 사용.
    /// `text`는 자막 원문, `title`은 영상 제목, `channel`은 채널명.
    static func summary(transcript text: String, title: String, channel: String) -> String {
        """
        다음 YouTube 영상의 자막을 분석하여 요약해 주세요.

        **반드시 모든 내용을 한국어로 답변하세요. 영어 사용 금지.**

        제목: \(title)
        채널: \(channel)

        자막 내용:
        \(text.prefix(15000))

        아래 정확한 형식으로 답변하세요:

        개요: (2~3문장 요약)

        핵심 포인트:
        • (핵심 포인트 1)
        • (핵심 포인트 2)
        • (핵심 포인트 3)

        챕터:
        • [0:00 - 2:30] 챕터 제목
        • [2:30 - 5:00] 챕터 제목

        챕터는 영상의 주요 내용 구간을 2~5개로 나누어 시간대와 함께 작성하세요.
        """
    }

    /// 단일 카테고리 태그 선택 프롬프트 — Gemini/OpenRouter 공통 사용.
    static func tag(title: String, channel: String, tags: [String]) -> String {
        """
        다음 YouTube 영상의 제목과 채널명을 보고 가장 적합한 태그를 선택해 주세요.

        제목: \(title)
        채널: \(channel)

        다음 태그 중 하나만 선택해 주세요: \(tags.joined(separator: ", "))

        답변은 선택된 태그 이름만 작성해 주세요. 다른 텍스트는 포함하지 마세요.
        """
    }
}