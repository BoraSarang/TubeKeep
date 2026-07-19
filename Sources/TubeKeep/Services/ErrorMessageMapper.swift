import Foundation

enum ErrorMessageMapper {
    static func map(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "알 수 없는 오류가 발생했습니다" }

        let lower = raw.lowercased()

        if lower.contains("http error 403") {
            return "영상에 접근할 수 없습니다 (권한 필요). 다른 영상을 시도해 보세요."
        }
        if lower.contains("http error 404") {
            return "영상을 찾을 수 없습니다. 주소를 확인해 주세요."
        }
        if lower.contains("http error 410") {
            return "영상이 삭제되었습니다."
        }
        if lower.contains("http error 429") {
            return "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요."
        }
        if lower.contains("ffmpeg") || lower.contains("mux") || lower.contains("merger") {
            return "파일 변환 중 오류가 발생했습니다. 다시 시도해 주세요."
        }
        if lower.contains("sign in") || lower.contains("age") || lower.contains("confirm your age") {
            return "연령 제한 또는 로그인이 필요한 영상입니다."
        }
        if lower.contains("private video") {
            return "비공개 영상입니다."
        }
        if lower.contains("copyright") || lower.contains("takedown") {
            return "저작권 문제로 다운로드할 수 없는 영상입니다."
        }
        if lower.contains("unavailable") || lower.contains("not available") {
            return "영상을 사용할 수 없습니다."
        }
        if lower.contains("live") && (lower.contains("ended") || lower.contains("not started")) {
            return "라이브 방송은 다운로드할 수 없습니다."
        }
        if lower.contains("premiere") {
            return "프리미어 영상은 다운로드할 수 없습니다."
        }
        if lower.contains("members-only") || lower.contains("member") {
            return "멤버십 전용 영상입니다."
        }
        if lower.contains("no formats") {
            return "다운로드 가능한 포맷이 없습니다."
        }
        if lower.contains("requested format") && lower.contains("not available") {
            return "선택한 화질을 사용할 수 없습니다. 다른 화질을 선택해 주세요."
        }
        if lower.contains("download") && lower.contains("denied") {
            return "다운로드가 차단되었습니다."
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        let cleaned = lines.map { line in
            line.components(separatedBy: "ERROR: ").last ?? line
        }.joined(separator: " ")

        if cleaned.count > 120 {
            return String(cleaned.prefix(120)) + "..."
        }
        return cleaned
    }
}
