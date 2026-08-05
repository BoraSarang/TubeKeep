# PLAN v2.9 — 리팩토링 (R1~R5) — macos

> 버전: v2.9-macos (비공개 리팩토링) · 작성: 2026-08-05

## 개요
코드 품질·유지보수를 위한 리팩토링. 기능 동작 변경 최소화, 1커밋 1관심사.

## 결정 사항
- R1: `YouTubeDLService.download/buildDownloadArgs/constructOutputTemplate`은 호출처 0건 → **제거** (실다운로드 경로 `DownloadManager` 유일화)
- R2: `AppReducer` statusBar 동기화 4회 + addToQueue 2회 중복 → 헬퍼 추출
- R3: 죽은 코드 3건 제거 + `parseFormats` 자기비교 버그 수정
- R4: `LibraryReducer+Podcast/QnA/Mindmap/Report` 헬퍼 → 독립 `@Reducer` + `.ifLet`/`.scope`
- R5: `SettingsView`(1098줄)·`MainView`(901줄) 하위 뷰 분리
- T1: `DownloadItemTests` "AAC vs MP3" 불일치 → 테스트 기대값 `AAC`로 정정 (실제 오디오 포맷)

## 구현 단계 (T-번호)
| ID | 작업 | 상태 |
|----|------|------|
| T-900 | PLAN_v2.9 + TODO 등록 | 완료 |
| T-901 | R1 yt-dlp 경로 단일화 | 완료 |
| T-902 | R2 AppReducer 중복 제거 | 완료 |
| T-903 | R3 죽은 코드+버그 | 완료 |
| T-904 | R4 LibraryReducer 분리 | 완료 (Report·Mindmap fff8efa, QnA·Podcast fd74e7f) |
| T-905 | R5 뷰 분해 | 완료 |
| T-906 | T1 테스트 정리 + swift test 76/76 | 완료 |

## 테스트 계획
- 각 단계: `./build_and_run.sh debug macos --no-launch` 성공
- 최종: `swift test` 76/76 (R4 전 중간 76/76 확인)
- 플레이어/다운로드 실시나리오는 앱 재실행으로 확인

## 롤백
- git revert per 커밋 / 각 커밋 독립 (R1~R5 분리)

## 검증
- `swift test` · `build_and_run.sh debug macos` · CHANGELOG/세션 로그