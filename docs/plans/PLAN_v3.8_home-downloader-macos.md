# PLAN v3.8 — 홈(영상 다운로더) 로그 통합 + AI 요약 제거 + 다운로드 형식 버그 수정 (macOS)

## 1. 개요

홈(영상 다운로더) 화면 작업 요청 3건을 처리한다.

1. **동작 로그 → 디버그 로그 통합** — 영상 정보 조회 시 화면 하단에 렌더링되는 동작 로그(`fetchLogs`)를 제거하고, 동일 내용을 `DebugLogManager`로 출력한다. (다른 화면들은 이미 디버그 로그로 통합되어 있고 Home만 빠져 있었음)
2. **Home AI 요약 제거** — 영상 조회 후 ALE려면 "AI 요약" 버튼/팝오버/Gemini 키 알림을 Home 화면에서 제거한다. `SummarizationService`는 보관함/Library, 유휴 자동화 등 다른 곳에서 여전히 쓰므로 **서비스 자체는 유지**하고 Home의 UI/액션만 제거.
3. **다운로드 `-f` 형식 문자열 이중 반복 버그 수정** — `DownloadManager.buildDownloadArgs`에서 `/` 포함 formatId(예: `best[height<=360]/best`)가 `"\(id)/\(id)"`로 이중 반복되어 `best[height<=360]/best/best[height<=360]/best`가 전달되는 버그. 또한 진행률 미표시(시작만 되고 진행/완료 로그 없음) 원인을 점검·보정한다.

## 2. 결정 사항

| 항목 | 결정 |
|------|------|
| 동작 로그 렌더 | Home 화면에서 완전 제거. `[VideoInfo]` 카테고리로 `DebugLogManager.append` 출력 |
| `fetchLogs` State | 제거 (App/Home State 초기화, Action 정리) |
| AI 요약 | Home의 `summary*`/`showSummaryPopover`/`showGeminiKeyAlert` 상태 + 요약 액션 7종 제거. `SummarizationService`는 유지 |
| 다운로드 형식 버그 | `/`,`+` 포함 formatId는 그대로 전달 (이중 반복 금지). 비디오 에이스터 스트림 분기는 `id/filter` 단일 구성 |
| 진행 로그 원인 | `--progress-template` 문자 그대로 stdout 파싱 로직 점검, 빠뜨린 `[INFO]` 접두 무시 보정 |

## 3. 아키텍처

### 3.1 HomeReducer 변경
- `State`에서 `fetchLogs` 제거 → `fetchProgressLog` 액션이 `DebugLogManager.append("[VideoInfo] ...")`로 전환
- 요약 관련 State/Action 제거:
  - State: `summaryText`, `summaryProvider`, `summaryLoading`, `showSummaryPopover`, `showGeminiKeyAlert`
  - Action: `requestSummary`, `summaryLoaded`, `summaryFailed`, `toggleSummaryPopover`, `dismissSummary`, `setGeminiKeyAlert`, `openSettingsForGeminiKey`
  - `startFetch`/`infoResponse`/`infoFailed`/`resetInfo`/`cancelFetch`에서 위 상태 초기화 코드 제거
- `case .fetchProgressLog` 처리 수정

### 3.2 HomeView 변경
- `fetchingIndicator`의 `#if DEBUG` 로그 박스(펼치기/접기 포함, `showFullLog` State) 제거 → 로딩 스피너 + 취소만 유지
- "AI 요약" 버튼 + popover 제거
- "Gemini API 키 필요" alert 제거 (`showGeminiKeyAlert` 제거)

### 3.3 DownloadManager 변경
- `buildDownloadArgs` formatId 로직 수정:
  ```swift
  let id = item.selectedFormat.id
  if id.contains("/") || id.contains("+") { return id }  // 이미 체인/병합
  if item.selectedFormat.isVideoOnly { ... }
  if id.hasPrefix("best") { ... }
  return "\(id)/\(id)"
  ```
- `isVideoOnly` 폴백이동 `id/bestvideo+bestaudio` 중복 방지
- 진행률 파싱: yt-dlp 메시지 접두사(`[download] ` 등)로 `Double` 파싱 실패 방지 위한 `[download]` 접두 제거 보정 검토

## 4. 구현 단계

| T-번호 | 작업 | 상태 |
|--------|------|------|
| T-1088 | PLAN v3.8 문서 + TODO 등록 | 예정 |
| T-1089 | HomeReducer 로그 통합 + 요약 제거 | 예정 |
| T-1090 | HomeView 로그 박스/요약 UI 제거 | 예정 |
| T-1091 | DownloadManager 형식 버그 수정 | 예정 |
| T-1092 | 빌드 + 검증 (로그 배출 확인) + CHANGELOG | 예정 |

## 5. 테스트 계획

- 빌드: `./build_and_run.sh debug macos`
- TC-1: URL 조회 시 화면 하단 로그 박스가 없고, Debug 패널에 `[VideoInfo]` 로그가 배출되는지 확인
- TC-2: Home에 AI 요약 버튼이 없음, Library/AI Window 요약 기능은 그대로 동작
- TC-3: 채널/홈 다운로드 시 `-f` 형식이 `best[height<=360]/best` 단일(반복 없음)으로 전달되는지 Debug 로그로 확인 + 다운로드 완료 진행

## 6. 롤백 계획

- git revert 해당 커밋 또는 개별 파일 복원 (reducer/view/manager 변경 포함)
- `fetchLogs`는 pure UI/Debug이므로 사용자 영향 낮음
- AI 요약 버튼 재추가는 이 커밋 revert로 복원 가능

## 7. 문서 업데이트

- `docs/TODO.md` (T-1088~1092)
- `docs/CHANGELOG.md` (v3.8 섹션)
- `.agent/session-2026-08-09-macos.md` (세션 로그)