## 변경 사항

| 항목 | 내용 |
|------|------|
| 플랫폼 | macOS |
| 에러코드 | `GeminiError.errorCode` 추가 (`E-COM-API-*`, `E-COM-NET-*`) |
| GBridge 모듈 | N/A (macOS 단일 플랫폼) |

## 검증

- [x] `./build_and_run.sh debug macos` 성공 (빌드 + 실행)
- [x] DebugPanel에서 ERROR 로그 0개 확인
- [x] 74/76 테스트 통과 (2개 사전 존재 실패, 리팩터링과 무관)
- [x] 스크린샷 Before/After — 리팩터링은 UI 변경 없음 (코드 정리 전용)

## 성능 영향

- Cold Start: 변화 없음 (코드 정리만 수행)
- 메모리: 변화 없음
