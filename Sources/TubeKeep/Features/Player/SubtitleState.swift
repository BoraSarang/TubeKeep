import Foundation

/// 자막 로딩 상태 — PlayerReducer의 `subtitleLoading`/`subtitleError`/`subtitleAvailable`
/// 3개 필드를 하나의 enum으로 통합한다.
enum SubtitleState: Equatable {
    /// 확인 전 / 초기 상태
    case idle
    /// 자막 확인·로딩 중
    case loading
    /// 자막 유무 확인 완료 (파라미터 = 유무)
    case available(Bool)
    /// 자막 로딩 실패/삭제 등 오류 (파라미터 = 메시지)
    case failed(String)
}
