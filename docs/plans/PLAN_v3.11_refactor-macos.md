# PLAN v3.11 — 안정성 버그 정화 + 채널 ID 정규화 + AI 폴백 통합 + 구조 개선 (macOS)

## 개요
v3.10까지 전체 코드베이스 정밀 분석(Services/AI/Reducer/UI 4개 영역)에서 확인된 이슈를 4단계로 해결한다.
**원칙**: 사용자 경험(UX) 불변, 각 커밋마다 빌드 + `swift test` 통과, 1커밋 1관심사.

## 1단계: 버그 정화 (안정성)

### T-A. 프로세스 고아화 3건
| 파일 | 문제 | 수정 |
|------|------|------|
| `DownloadManager.swift:255-262` | `cancelDownload`가 `terminate()`만 호출, stdout/stderr 핸들러 미정리 + `waitUntilExit` 미대기 | `terminate()` 후 async 대기 + 핸들러 nil 정리 |
| `SummarizationService.swift:200-214` | `runProcess`가 Plane continuation, Task 취소 시 프로세스 계속 실행 | `withTaskCancellationHandler`로 취소 시 `terminate()` |
| `TTSService.swift:180-198` | `convertMP3ToAIFF`가 `waitUntilExit()` 동기 블록 | async 폴링 + 취소 시 terminate |

### T-B. 콜백/Continuation 누락 2건
| 파일 | 문제 | 수정 |
|------|------|------|
| `TTSService.swift:19-32` | `speak(completion:)` 콜백이 delegate에서 호출 안 됨 | `speechSynthesizer(didFinish/didCancel)`에서 `completion?()` + 재진입 가드 |
| `EdgeTTSClient.swift:47-119` | `withCheckedThrowingContinuation` Task 취소 시 hang | `withTaskCancellationHandler` + `webSocket.cancel()` |

### T-C. DB 크래시 2건
| 파일 | 문제 | 수정 |
|------|------|------|
| `DatabaseManager.swift:148` | `sqlite3_errmsg` 결과 `errMsg!` 강제 언랩 | `String(cString:)` 안전 변환 |
| `DatabaseManager.swift:759,772` | `SQLITE_STATIC` 바인딩 use-after-free | `SQLITE_TRANSIENT` 통일 |

## 2단계: 채널 ID 정규화 + 아바타 캐시 중앙화

### T-D. 채널 ID 교정 단일화
- `LibraryCacheService` 채널 ID(핸들 `UC_...` vs 실제 24자) 교정 규칙 4곳 → `normalizeUserID()` 1곳
- 앱 시작 시 보관함/구독의 `UC_` 핸들을 실제 ID 복구하는 마이그레이션 헬퍼

### T-E. 아바타 캐시 1차 소스 통일
- View 3~4곳 중복된 아바타 URL 병합/캐시 로직 → `LibraryCacheService` 단일 진실 (v3.10 작업과 연계)

## 3단계: AI 폴백 체인 통합

### T-F. LLMChainExecutor 신설
- Summarization/Tagging/ChannelInsight/SimilarVideo에 복붙 4벌 → 체인 정의 1개, 서비스별 단계 조합만 주입

### T-G. 요약 프롬프트 단일화
- `SummarizationService:385-410` / `OpenRouterService:28-53` / `AX4Service:31-56` (동일) → `LLMPrompts.swift` 1벌

### T-H. 응답 파서 단일화
- OR/AX4/Gemini 파서 3벌(`hasPrefix` vs `lowercased().contains` 분화) → `SummaryParser` 1벌
- `classifyTag`: OR 10개 vs AX4 18개 태그 불일치 → 태그 세트 통일

### T-I. HTTP 요청/재시도 공통화
- HTTP 요청 4벌 + 재시도 정책 제각각 → `LLMHTTPClient` 1벌 + 공통 지수 백오프

### T-N. A.X 4.0(AX4) 서비스 전면 제거 (사용자 요청)
- SKT A.X 4.0 게스트 API(`guest-api.sktax.chat`) 서비스 종료 → 기능 전체 삭제
- 삭제 대상: `AX4Service.swift`(파일 삭제), `AX4Error`, `summarizeWithAX4`, `classifyWithAX4`, `Settings.ax4APIKey`, `SettingsReducer.setAX4APIKey`, `SettingsAITab` A.X 4.0 섹션, `Constants.defaultAX4APIKey`
- 폴백 체인 변경: 요약 `OpenRouter → yTeaser → Gemini`, 태깅 `OpenRouter → Gemini → 규칙`
- 호출부 파라미터 제거: `SummarizationService.summarizeVideo`, `TaggingService.classify`, `LibraryReducer` 4곳, `IdleSubtitleService` 2곳

### T-O. AI 폴백 체인 성능순 재배치 (사용자 요청)
- 기존 체인은 "비용순(무료→유료)" 배치 → **성능순**으로 재배치 (Gemini Flash 1순위)
- 요약: `Gemini → OpenRouter → yTeaser` (Gemini 할당량 초과/실패 시 자동 폴백)
- 태깅: `Gemini → OpenRouter → 규칙(autoClassify)` (yTeaser는 요약 전용이라 태깅 미사용)
- `SettingsAITab` LLM 섹션 화면 배치도 Gemini → OpenRouter → yTeaser 순으로 재배치 + 우선순위 라벨 추가

## 4단계: 구조 개선

### T-J. AppDelegate 분해 (925줄)
- `WindowFactory`: 9개 창 생성 중복 ~180줄 통일 (identifier/styleMask/center)
- `CommandHandler`: 특수키 핸들러 74줄 분리

### T-K. LibrarySidebarView 분해 (871줄)
- 7개 섹션 서브뷰 분리 + `SidebarSelectableRow` 행 통일

### T-L. 자막 상태 enum 전환
- `PlayerReducer` 자막 상태 5개 boolean → `enum SubtitleState` + Whisper 블록 분해

### T-M. debounce + 정리
- `saveSettings` debounce 0.5s, 검색 `.debounce 300ms`
- dead code: `insertFTSIndex`, `Format.isAudioOnly`, `ProcessRunner.ProgressUpdate`, `showSubtitleToastToast`

## 테스트 계획
- 1~4단계 각각 `swift build` + `swift test` (기준선 76/76) 통과
- 2단계: 사이드바 ↔ 채널 콘텐츠 ↔ 다운로더 아바타 동일성 수동 확인
- 3단계: 요약/태깅/채널 인사이트 폴백 동작 수동 확인 (DB 캐시로 재시도 없음)

## 롤백 계획
- `git revert` + `./build_and_run.sh debug macos`
- 3단계가 위험하면 2단계까지 유지하고 별도 브랜치로 분리

## 성능 예산
- debounce 도입으로 saveSettings 동기 인코딩(30곳) 감소, Cold Start 영향 없음

## 에러코드
- `E-MAC-AI-1003` "AI 응답 파싱 실패" 추가 (error_message_ko.json)