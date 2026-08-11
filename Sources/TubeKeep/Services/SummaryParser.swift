import Foundation

/// AI 요약 응답 파싱을 한 곳에서 관리한다.
/// - `parse`: 개요(overview)/핵심 포인트(keyPoints)/챕터(chapters) 구조 파싱
/// - `parseChapterLine`: 챕터 한 줄 → `ChapterInfo` 변환
/// - `predefinedTags`: 태깅용 카테고리 세트 (단일 진실)
enum SummaryParser {
    /// 태깅/분류에 사용하는 카테고리 세트 — Gemini/OpenRouter 공통.
    static let predefinedTags = [
        "기술/IT", "음악", "게임", "뉴스/시사",
        "스포츠", "엔터테인먼트", "교육/강의",
        "요리/음식", "여행/일상", "과학",
    ]

    /// 요약 응답을 파싱해 (overview, keyPoints, chapters) 튜플로 반환한다.
    static func parse(_ response: String) -> (overview: String, keyPoints: [String], chapters: [ChapterInfo]) {
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var overview = ""
        var keyPoints: [String] = []
        var chapters: [ChapterInfo] = []
        var inKeyPoints = false
        var inChapters = false

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("개요") || lower.contains("overview") {
                inKeyPoints = false
                inChapters = false
                continue
            }
            if lower.contains("핵심") || lower.contains("key point") {
                inKeyPoints = true
                inChapters = false
                continue
            }
            if lower.contains("챕터") || lower.contains("chapter") {
                inKeyPoints = false
                inChapters = true
                continue
            }

            if inKeyPoints {
                let cleaned = line
                    .replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    keyPoints.append(cleaned)
                }
            } else if inChapters {
                if let chapter = parseChapterLine(line) {
                    chapters.append(chapter)
                }
            } else if !overview.isEmpty {
                overview += " " + line
            } else {
                overview = line
                    .replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        if overview.isEmpty && !lines.isEmpty {
            overview = lines[0]
        }

        return (overview, Array(keyPoints.prefix(5)), chapters)
    }

    /// 챕터 한 줄을 파싱 — `[0:00 - 2:30] 제목` / `1. [00:00-02:30] 제목` / `- 0:00~2:30 제목` 형태 지원.
    static func parseChapterLine(_ line: String) -> ChapterInfo? {
        let patterns = [
            #"^\d+[\.\)]\s*\[?(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–~]\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+)$"#,
            #"^[\-\*•]\s*\[?(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–~]\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+)$"#,
            #"^\[?(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–~]\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let startStr = String(line[Range(match.range(at: 1), in: line)!])
                let endStr = String(line[Range(match.range(at: 2), in: line)!])
                let title = String(line[Range(match.range(at: 3), in: line)!]).trimmingCharacters(in: .whitespaces)
                let startTime = parseTimeToSeconds(startStr)
                let endTime = parseTimeToSeconds(endStr)
                if !title.isEmpty {
                    return ChapterInfo(title: title, startTime: startTime, endTime: endTime)
                }
            }
        }
        return nil
    }

    private static func parseTimeToSeconds(_ time: String) -> Double {
        let parts = time.split(separator: ":").map { Double($0) ?? 0 }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return parts.first ?? 0
        }
    }
}