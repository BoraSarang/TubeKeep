# CHANGELOG

## v3.11 — AI 폴백 체인 단일화 (macOS, T-1109~T-1116) ✅

### 리팩토링
- **LLMChainExecutor 신설 (T-1109)**: 폴백 체인 로직이 4곳(Summarization/Tagging/ChannelInsight/SimilarVideo)에 복붙되어 있던 것을 단일화
  - `LLMChainStep<Output>`(provider/isAvailable/execute/validate) + `LLMChainExecutor.run` — 순차 시도 후 첫 성공 반환, 모두 실패 시 nil
  - `SummarizationService.summarizeVideo`: Gemini→OpenRouter→yTeaser 체인을 Step 배열로 재구성
  - `TaggingService.classify`: Gemini→OpenRouter→규칙 (validate로 프리셋 매칭 검증)
  - `ChannelInsightService.summarize`: OpenRouter→Gemini
  - `SimilarVideoService.buildQueriesFromAI`: OpenRouter→Gemini (JSON 배열 파싱 검증)
  - `LLMChainStepError.invalidOutput` — 출력 파싱 실패 시 다음 단계로 넘기는 오류 추가
- **LLMPrompts 단일화 (T-1110)**: 요약/태깅 프롬프트가 Gemini(영문 라벨)·OpenRouter(한글 라벨)로 분화된 것을 `LLMPrompts.swift` 1벌로 통일
  - `LLMPrompts.summary(transcript:title:channel:)` — Gemini/OpenRouter 요약 공통
  - `LLMPrompts.tag(title:channel:tags:)` — Gemini/OpenRouter/Tagging 태깅 공통
- **SummaryParser 단일화 (T-1111)**: 요약 응답 파서가 OR/AX4/Gemini 3벌로 분화된 것을 `SummaryParser.swift` 1벌로 통일
  - `SummaryParser.parse` — 개요/핵심 포인트/챕터 구조 파싱 (Summarization·OpenRouter 공통)
  - `SummaryParser.predefinedTags` 10개 — 태깅 카테고리 단일 진실 (Gemini/OpenRouter 공통)
  - `SummaryParser.parseChapterLine` — 챕터 한 줄 파싱 (AIWindowView에도 적용)
  - 각 서비스의 중복 파서(`parseSummaryResponse`/`parseChapterLine`/`parseTimeToSeconds`) 제거
- **LLMHTTPClient 공통화 (T-1112)**: HTTP 요청/재시도 로직이 Gemini(429 4회·지수백오프)·OpenRouter(모델 폴백)·yTeaser로 제각각이던 것을 `LLMHTTPClient.swift` 1벌로 통일
  - `LLMHTTPClient.postJSON` — POST JSON + Bearer 인증 + 추가 헤더 + 429 지수 백오프 재시도 + 상태 로깅 훅
  - `GeminiService.query` / `OpenRouterService.sendRequest` / `SummarizationService.summarizeWithYTeaser` 공통 적용
- **WindowFactory 분해 (T-1113 일부)**: AppDelegate에 중복되던 9개 창 생성 코드(identifier/styleMask/center/activate ~180줄)를 `App/WindowFactory.swift`로 통일
  - `WindowFactory.makeWindow` — SwiftUI 뷰 → 공통 설정 NSWindow 구성 (size/styleMask/zoom/level/background)
  - `WindowFactory.present` — center + makeKeyAndOrderFront + activate 공통화
  - 적용 창: lib/downloader/batch/channel/about/settings/qna/debugLog 8개 (player는 PlayerWindow 서브클래스라 유지)
- **KeyCommandHandler 분리 (T-1113)**: AppDelegate에 있던 전역 키 이벤트 처리(스페이스 토글/설정/디버그 단축키)를 `App/KeyCommandHandler.swift`로 분리
  - 콜백 주입(isPlayerKeyWindow/onTogglePlayerPlayPause/onOpenSettings 등)으로 AppDelegate 상태 접근 유지
- **SidebarSelectableRow 신설 (T-1114)**: LibrarySidebarView에서 5개 행(nav/filter/category/history/profile)이 반복하던 HStack+선택 배경+버튼 스타일을 `Features/Library/SidebarSelectableRow.swift`로 통일
  - 아이콘/카운트/trailing(ProgressView) 옵션 지원, LibrarySidebarView 865→797줄
- **SubtitleState enum 전환 (T-1115)**: PlayerReducer의 자막 상태 3개 필드(subtitleLoading/subtitleError/subtitleAvailable)를 `Features/Player/SubtitleState.swift`의 `enum SubtitleState`(idle/loading/available/failed)로 통합
  - `SubtitlePanel`은 isLoading/subtitleAvailable/errorMessage 3개 파라미터 대신 subtitleState 하나를 받도록 단순화
- **debounce/dead code 정리 (T-1116)**:
  - 검색(`setSearchText`) 300ms + `saveSettings` 0.5s debounce — TCA 1.26의 `clock.sleep` + `.cancellable(cancelInFlight:)` 패턴으로 적용
  - dead code 제거: `DatabaseManager.insertFTSIndex`(미사용), `ProcessRunner.ProgressUpdate`(미참조)
  - `Format.isAudioOnly`/`showSubtitleToastToast`는 실제 사용 중이라 유지

### 검증
- `swift build` ✅ (기존 경고만 — TTSService conformance, libmpv 26.0)
- `swift test` ✅ 76/76 통과

---

## v3.10.0 — 채널 아바타 동기화 + AI 폴백 성능순 재배치 (macOS, T-1099~T-1102, T-1118~T-1119) ✅

### 기능/변경
- **AI 폴백 체인 성능순 재배치 (T-1119)**: 할당량이 거의 없는 Gemini를 1순위, 무료 한도가 넉넉한 OpenRouter를 2순위로 재배치
  - 요약: Gemini → OpenRouter → yTeaser (`SummarizationService`)
  - 태깅: Gemini → OpenRouter → 규칙 기반(`autoClassify`) (`TaggingService`)
  - 설정 UI(`SettingsAITab`)의 LLM 섹션도 동일 순서(Gemini→OpenRouter→yTeaser)로 재배치 + 순위 라벨 추가(Gemini "1순위·할당량 초과 시 자동 폴백", OpenRouter "2순위 폴백", yTeaser "3순위 폴백"), 폴백 순서 설명 문구 갱신
  - `docs/AI_MODELS.json`의 `default_chain`/`summary.chain`/`tagging.chain` 갱신, qna·podcast 체인은 실제 코드(OpenRouter 전용)와 일치하도록 교정
- **A.X 4.0 전면 제거 (T-1118)**: AX4Service 삭제 + 폴백 체인 단순화

### 버그 수정
- **보관함 사이드바 아바타 미갱신**: 채널 정보 갱신 시 콘텐츠 헤더 아바타만 갱신되고 사이드바는 그대로 남던 문제 — `CachedAvatarView`에 `.onChange(of: url)` + `channelInfoDidUpdateNotification` 구독을 추가해 모든 화면 자동 재로드
- **채널 다운로더 아바타 미갱신**: `ChannelDownloaderView.refreshChannelInfo`가 avatarURL만 저장하고 이미지 캐시·통지 발행을 하지 않던 문제 — 아바타 다운로드→`cacheAvatar`→통지 발행 추가
- **빈 아바타(사이드바/채널 목록)**: avatarURL이 빈 채널(예: `fetchAvatarURL` 실패로 `""` 저장)이 디스크 캐시(`avatar_<channelId>.jpg`)에 이미 이미지가 있어도 안 나오던 문제 — `loadAvatar`가 캐시를 url 검사보다 **먼저** 조회하도록 수정. url과 무관하게 channelId 키 공유 캐시가 있으면 표시
- **양방향 동기화**: 어느 화면에서든 갱신하면 `channelInfoDidUpdateNotification` 하나로 사이드바/콘텐츠 헤더/채널 목록이 함께 갱신

### 파일
- `Sources/TubeKeep/Features/Settings/SettingsAITab.swift`, `Sources/TubeKeep/Services/SummarizationService.swift`, `Sources/TubeKeep/Services/TaggingService.swift`
- `Sources/TubeKeep/Views/CachedImageViews.swift`, `Sources/TubeKeep/Features/Channel/ChannelDownloaderView.swift`, `Sources/TubeKeep/Features/Channel/ChannelContentView.swift`, `Sources/TubeKeep/Features/Channel/ChannelListView.swift`
- `docs/AI_MODELS.json`, `docs/TODO.md`, `docs/plans/PLAN_v3.11_refactor-macos.md`, `README.md`

### 검증
- `swift build` ✅ (Build complete 9.55s, 기존 경고만 — libmpv 26.0)
- 실측: `~/Library/Caches/com.tubekeep/avatar_*.jpg` 38개 존재, 지무비(`UCaHGOzOyeYzLQeKsVkfLEGA`, avatarURL 비어있음)도 캐시 파일 존재

---

## v3.9 — 다운로드 유령 완료 방지 + 재개/임시물 보존 + 보관함·히스토리 누락 보정 (macOS, T-1093~T-1098) 🚧

### 버그 수정
- **유령 완료(ghost-complete) 방지**: 종료·실패 시 일부 항목이 `completed 100% + 실파일 없음`으로 잘못 기록되던 문제 수정
  - 확장자·크기 검증: `.webp`(썸네일)·`.jpg`·`.png`·`.part`(임시)를 완료 미디어로 착각하지 않도록 `isValidMediaFile`(확장자+크기>0) 검증 추가 — `DownloadManager.resolveActualPath`, `checkExistingFile`, 채널 폴백 모두 적용
  - ID 폴백 `contains(videoId)` → 검증된 실제 미디어 파일(썸네일/임시 제외)만 인정
  - 완료 판정 후 미디어가 없으면 `completed` → `pending`으로 자동 전환(revalidation) — 재다운로드 대기
- **`.part`·임시물 보존**: 앱 종료 시 `cleanupTempFiles`가 실제 미디어가 없는 항목의 `.part`/`.webp`를 삭제해 재개를 막던 것을, 확장자 검증으로 보존 — `7B862YcjxsA` 116MB `.part` → 실제 170MB `.mp4` 완료 재개 성공
- **`isComplete(revalidation:true)` 재검증 경로 보정**: `findAndReplaceFile` 내 파일 실존 확인 + 미디어 검증으로 신뢰성 상승

### 기능
- **히스토리·보관함 누락 보정(B)**: 앱 시작 `itemsLoaded`에서 `downloaded.contains(id)` 만으로 완료 처리하던 것을 실제 미디어 검증으로 교체, 보관함 등록(`LibraryItem`) 및 다운로드 히스토리(`download_history`) 기록이 누락된 사례를 교차 보정
- **완료된 항목 재검증**: 로드 시 `completed` 항목에 대해 실미디어가 없으면 `pending` 전환 → `invalidated` 목록 분리 → `checkExistingFile` 없으면 히스토리에서 제거(hidden)
- **`saveDownloadHistory` UUID 중복 방지**: `download_history` 등록 시 `video_id` 기반 중복 검사 (INSERT 불필요 시 skip) + `download status = completed`인 항목 파일 검증 필터

### 검증
- `./build_and_run.sh debug macos` ✅ (빌드 성공, 앱 실행 정상)
- 실제 다운로드 검증: `jpgW5UBPbtQ`(빵빵사운드 PLAYLIST) 79.5%→88.4% 진행 후 `completed` 전환 확인, `.part`→`mp4`(265MB) 완성. 다음 항목(`auVCvCdK4_4`) 자동 시작 확인
- 유령 3건(`jpgW5/auVC/Ux5s`) 재검증 → pending 전환 + 재다운로드 확인
- 보함함 7B862 항목 표시(UI 갱신 로드) 확인

## v3.8 — 홈 다운로더 로그 통합 + AI 요약 제거 + 형식 버그 수정 (macOS, T-1088~T-1092) 🚧

### 변경
- **홈(영상 다운로더) 동작 로그 → 디버그 로그 통합**: 영상 정보 조회 시 화면 하단에 렌더링되던 동작 로그 박스(`fetchLogs`, 펼치기/접기)를 제거하고, 동일 내용을 `DebugLogManager`에서 `[VideoInfo]` 카테고리로 출력. 다른 화면들은 이미 디버그 로그로 통합되어 있었는데 Home만 누락된 것을 정리
- **Home AI 요약 제거**: 홈 영상 조회 후 "AI 요약" 버튼/팝오버 및 "Gemini API 키 필요" 알림 제거. `Summary` 관련 State(`summaryText`/`summaryProvider`/`summaryLoading`/`showSummaryPopover`/`showGeminiKeyAlert`)와 Action 7종(`requestSummary` 등)을 `HomeReducer`에서 삭제. `SummarizationService`는 보관함(Library)/AI Window/유휴 자동화에서 계속 사용하므로 **그대로 유지** (다른 곳 영향 없음)

### 버그 수정
- **`-f` 형식 문자열 이중 반복**: `DownloadManager.buildDownloadArgs`의 formatId 로직에서 `/` 또는 `+`를 포함한 formatId(예: 채널 다운로더의 `best[height<=360]/best`)가 `"\(id)/\(id)"` 분기에 걸려 `best[height<=360]/best/best[height<=360]/best`로 이중 반복되던 것 수정. 이제 `/`·`+` 포함 id는 그대로 전달. 비디오/오디오 분리는 단일 폴백 체인으로 구성
- **진행률 파싱 오류**: `--progress-template` 출력이 `[download] 45.2%|...` 형태일 때 `Double("[download] 45.2")` 파싱 실패로 진행률이 뜨지 않던 것 → `[download]` 접두 제거 후 파싱하도록 보정

### 검증
- `./build_and_run.sh debug macos` ✅ (Build complete 10.69s, 앱 실행 정상)
- `swift test` ✅ 76개 테스트 통과

## v3.6 — 유휴 자동화 반복 처리·팝업 안정화 (macOS, T-360~T-363) 🚧

### 버그 수정
- **유휴 자동화 무한 반복(같은 영상 재작업) 해결**: `DatabaseManager.updateTranscript`가 순수 `UPDATE`라서 `video_ai_data`에 해당 `video_id` 행이 없으면 Whisper/다운로드로 생성한 자막이 저장되지 않고 휘발됨 → 매 사이클 같은 영상(cU1rgvWwSas 등)을 80초 Whisper로 반복 생성 → "총 84개"가 줄지 않는 문제. `INSERT ... ON CONFLICT(video_id) DO UPDATE`(UPSERT)로 변경해 최초 등록/갱신 모두 처리 (기존 summary/chapters는 `COALESCE`로 보존, `INSERT OR REPLACE` 사용 안 함)
- `markSubtitleFailed`도 동일한 순수 UPDATE 버그 → UPSERT로 변경 (실패 마킹 휘발 방지)
- **시작/중단 팝업 디바운스 120초** — 유휴가 잠깐 풀릴 때 `시작→중단→재시작` 반복 시 중복 알림 억제 (`IdleSubtitleService.logAndNotify`), ActivityLog는 항상 기록
- **유휴 해제 유예 30초 → 60초** — whisper 중 짧은 마우스 이벤트로 인한 불필요한 중단 감소
- 유휴 이탈 시 디버그 로그에 실제 시스템 idle 초/임계값 포함

### 검증
- `./build_and_run.sh debug macos` ✅ (빌드 성공, 앱 실행 정상)
- **21:45 idle_activity.log 검증 완료**: Whisper 성공 영상은 AI 단계에서 `DB에서 캐시된 자막 로드 성공(14814자)` → 요약·태그 정상 완료 → 다음 영상 3개 연속 처리 (기존엔 같은 영상 무한 재작업). 시작 팝업 1회, 중단 팝업 0회. 유휴 해제가 2회 발생했으나 60초 유예 중 재유휴로 중단 없이 진행 — **반복 루프 해결 확인**

## v3.5 — 휴지통 + 사이드바 채널 전체 삭제 + 용어 정리 (macOS, T-350~T-358) 🚧

### 기능 추가
- **휴지통 (soft delete)** — 기존 물리 삭제(복원 불가)를 앱 내장 휴지통으로 전환
  - `LibraryItem.trashedAt` 필드(v3.5), 보관함은 `trashedAt == nil`만 표시
  - 삭제 = 원본 미디어 파일을 `{저장폴더}/.Trash/{videoId}/`로 이동 + sidecar(`original_path.json`)로 원위치 기록 (`LibraryCacheService` 휴지통 서비스 T-352)
  - 복원: 원본 채널 폴더로 되돌림(transcript/AI 데이터 유지), 영구 삭제: 기존 `purgeAssociatedData`+`download_history` 정리
  - 사이드바에 **"휴지통"** 진입(`TrashView`) — 항목별 복원/영구 삭제, 전체 비우기, 30일 경과 자동 정리(AppDelegate 시작 시, T-357)
  - 디스크 사용량 계산은 `.Trash`(히든 폴더) 제외
- **사이드바 채널 우클릭 "채널 영상 모두 삭제"** (T-354) — 확인 Alert 후 휴지통 이동 + 해당 채널 `download_history` 정리 (`trashChannelItems`)
  - 단, 채널 다운로더의 기존 "채널 삭제"는 영구 삭제 유지
- **용어 통일** — 보관함 메뉴 "라이브러리에서 삭제" → **"휴지통으로 이동"**, 선택 삭제(SelectionBar)도 휴지통 이동으로 전환 (T-355)
- `DatabaseManager.deleteDownloadHistory(videoId:)` 추가 (영구 삭제/채널 삭제 시 히스토리 정합성 개선)

### 검증
- `./build_and_run.sh debug macos` ✅ (빌드 성공, 앱 실행 정상)

## 개발 중 — 비슷한 영상 검색 (macOS, T-1084~1087)

### 기능 추가
- **비슷한 영상 검색** — 재생 중 영상의 제목·채널·AI 카테고리 태그를 AI 체인(OpenRouter→Gemini→규칙 폴백)으로 분석해 한글 검색어 3~4개 생성, `yt-dlp ytsearch`(기존 `TrendingService.search`)로 실제 유튜브에서 유사 영상 검색 (`SimilarVideoService.swift`)
- 검색어 캐시: UserDefaults `similarQueriesCache` (videoId별, TTL 7일) — LLM 비용 절감
- 플레이어 툴바 **"비슷한 영상" 버튼** → 오른쪽 사이드 패널(로딩/오류·재시도/빈 상태) — 자막/큐 패널과 상호 배타
- 목록 클릭 → 해당 영상으로 **즉시 재생 전환** (openPlayerWindow + PlayerItem) + 컨텍스트 메뉴(다운로드/유튜브에서 열기)
- 참고: YouTube 공식 API `relatedToVideoId` 2023 지원 종료로 검색어 기반 접근. 신규 API 키 불필요(기존 키 재사용)

## 보관함 카테고리 필터 (macOS, bd TubeKeep-iqp)

### 기능 추가
- 보관함 사이드바에 **카테고리** 섹션 추가 — 채널 목록 위, 보유 개수 내림차순 정렬 (`LibrarySidebarView`)
- 카테고리 선택 시 채널/최근 필터와 **상호 배타** (selectedChannel=nil, filterMode=.all), 같은 카테고리 재클릭 시 해제
- `LibraryReducer.State.selectedCategory` + `setSelectedCategory` 액션, `filteredItems`에 `tags.contains(category)` 필터 추가
- 리포트/프로필과 동일한 `LibraryItem.tags` 기반 집계 (태깅 안 된 아이템은 "전체"에서만 노출)

## v3.1.1 (2026-08-06) — 정밀 분석 버그 수정 11종 (macOS) ✅

> v3.1 릴리즈 후 전체 소스 정밀 분석(118파일)에서 확인된 핵심 버그 11종을 수정. 빌드 + `swift test` 76/76 통과. (T-1050~T-1060)

### 버그 수정 (T-1050~T-1060)
- **T-1050 — DB 3종**: `download_history` 채널 삭제 SQL `channelName`→`channel_name` 컬럼명 수정(무력화 방지), `subtitles_json` ALTER TABLE 중복 실행 방지(`columnExists` PRAGMA 체크), `qna_history` NULL 컬럼 크래시 방어(`columnText ?? ""`)
- **T-1051 — Settings 전체 리셋 방지**: `init(from:)` 전 필드 `decodeIfPresent` + 기본값 전환 (키 누락 시 일부만 기본값, 나머지 유지)
- **T-1052 — SwiftDataMigration 재시도**: 성공/실패 Bool 반환, 실패 시 완료 플래그 미설정 + `[Migration]` DebugLog
- **T-1053 — App Group**: `appGroupSuiteName`을 실제 entitlements 값 `group.com.tubekeep`으로 수정
- **T-1054 — 삭제 시 연관 데이터 정리**: `LibraryCacheService.purgeAssociatedData` — AI 데이터/QnA/FTS/썸네일 purge (영상 삭제 시 잔여 데이터 제거)
- **T-1055 — ProcessRegistry deadlock 해소**: lock 밖에서 terminationHandler 설정 (내부 lock 중첩 방지)
- **T-1056 — ProcessRunner 재작성**: stdout/stderr readabilityHandler drain(파이프 deadlock 방지), `withTaskCancellationHandler` + `kill(pid, SIGKILL)` 취소, `MutableData`+NSLock 데이터 레이스 방지, runSync 타임아웃/취소 처리
- **T-1057 — DownloadManager 취소 상태**: `canceledItems` 추적, `resumeDownload`/`cancelDownload` 상태 동기화, stderr 데이터 레이스 방지, 취소/일시정지 시 성공 오판 방지
- **T-1058 — YouTubeDLService stderr 크래시**: `data[Int(lastStderrSize)...]` → `Data(data.dropFirst(...))` 범위 크래시 방지 (2곳)
- **T-1059 — IdleSubtitleService 메인 블록/취소 경합**: `waitUntilExit()` → 100ms 폴링 + 120s 타임아웃 + nullDevice (UI 프리즈 해소), 취소 후 후속 처리 가드
- **T-1060 — ClipService 3종**: 클립 파일명 UUID 접미사 추가(1초 내 중복 저장 덮어쓰기 방지), 썸네일 생성 async 폴링(메인 블록 해소), `runFFmpeg` 취소 처리(`withTaskCancellationHandler` + SIGKILL + ProcessRegistry 등록)

### Verification
- `swift build -c debug` ✅ (기존 경고만 — SubscribedChannel Sendable, DigestService await, libmpv 26.0)
- `swift test` ✅ 76/76 (0 failures)
- 수동 테스트 항목: `docs/tests/v3.1.1.md` (TC-31-01~12, 기대 효과 포함)

## v3.1 (2026-08-06) — 유틸리티 기능 5종 (macOS) ✅

> v3.0 이후 유틸리티 기능 5종(클립 저장/카테고리, 채널 자동 다운로드, 전역 단축키, 유휴 자막 자동 다운로드, 디스크 정리) 구현 완료.

### Phase A — 클립 저장 & 카테고리
- **T-1040**: 플레이어에서 A-B 구간 클립 저장
  - `ClipItem` SwiftData 모델 (id/videoId/channelName/title/filePath/thumbnailPath/start/end/duration/createdAt) — `PersistenceController` ModelContainer 등록
  - `ClipService` — ffmpeg `-c copy`(재인코딩 없음) 컷 + `-progress pipe:1` 진행률 파싱 + 썸네일 캡처(`-frames:v 1`), `clipsRootDirectory`/`clipsDirectory`(`Documents/TubeKeep/Clips/<videoId>/`)
  - `ClipError` — invalidRange/duplicateRange(동일 A-B 구간 중복 저장 금지, ±0.1초)/encodeFailed
  - PlayerView 저장 버튼 + `ClipSavePopoverView`(진행바/경과/남은 시간) + 완료·중복 알림 배너, 저장 중 컨트롤바 숨김 방지
- **T-1041**: 클립 카테고리
  - `LibrarySidebarMode.clips` + `ClipView`(썸네일/채널명/구간/재생/Finder/삭제 contextMenu), `ClipReducer`(load/saveClip/deleteClip/deleteClipsForVideo)
  - 원본 영상 삭제 시 "클립도 삭제할까요?" NSAlert (`ClipService.confirmAndDeleteClipsIfAny`, 기본: 클립도 삭제)

### Phase B — 채널 자동 다운로드
- **T-1042**: `ChannelDownloadCache`에 `channelAutoDownload` 저장 키 + `isAutoDownloadEnabled`/`setAutoDownload`, ChannelContentView GroupBox "자동 다운로드" 토글(채널 전환 시 로드)
  - `ChannelUpdateService.enqueueAutoDownload` — 새 영상 발견 시 `downloadQueue.addItems`(settings.defaultResolution 기준)로 자동 큐 추가

### Phase C — 전역 단축키
- **T-1043**: `GlobalShortcutService` (Carbon RegisterEventHotKey + TISCopyCurrentASCIICapableKeyboardLayoutInputSource 키 표시)
  - `GlobalShortcutAction` 3종: 다운로더 열기 / 일괄 다운로더 열기 / 채널 다운로더 열기
  - SettingsSystemTab에 기록 UI(로컬 모니터 + `onDisappear` 해제), AppDelegate에서 `start()`
- **단축키 메뉴바 표시**: 메뉴바에 "다운로더" 메뉴 추가 — 전역 단축키가 설정된 항목은 키 등가물로 표시(⌘⌥S 등), command 미포함/특수키는 타이틀에 `\t단축키`로 표시, 단축키 변경 시 `GlobalShortcutService.didChangeNotification`으로 메뉴 실시간 갱신

### Phase D — 유휴 자막 자동 다운로드
- **T-1044**: `IdleSubtitleService` — `CGEventSource.secondsSinceLastEventType` 시스템 유휴 감지 + 15초 타이머
  - 유휴 시 자막 없는 최근 영상 순차 `yt-dlp --write-subs --skip-download` → `DatabaseManager.updateTranscript`, 사용자 입력 시 즉시 중단
  - 설정 키 `idleSubtitleMinutes`(끄기/5/10/30분), SettingsNotificationsTab Picker + 상태바 "자막 자동 다운로드" 표시

### Phase E — 디스크 정리
- **T-1045**: `DiskCleanupView` — 사이드바 "디스크 정리" 항목
  - 총 사용 용량 + 필터(모두/500MB+/1GB+/5GB+) + 정렬(용량/날짜/채널) + 개별/전체 선택 일괄 삭제
  - `LibraryReducer.removeItems([String])` 액션 추가 (클립 유무 확인 다이얼로그 포함)

### Verification
- `./build_and_run.sh debug macos` ✅ 매 단계 통과 (libmpv ld 경고는 기존 이슈)
- 클립 저장 실동작 검증 완료 (ffmpeg `-c copy`라 저장 매우 빠름)

## v3.0 (2026-08-06) — 전역 검색 + 플레이어 고도화 + scheme 통합 (macOS) ✅

> v2.9 리팩토링 후 첫 메이저 기능 버전. Phase A(검색)·B/B-2(플레이어)·D(scheme) 완료. Phase C(위젯)·브라우저 확장은 **진행하지 않음**으로 확정.

### Phase A — 전역 검색 보강
- **T-1003**: 검색 결과 스니펫 개선
  - `SnippetTextView` (Views) — FTS snippet의 `<b>` 마크업을 파싱해 검색어를 accent색 굵게 하이라이트
  - `SearchService.locateMatch(videoId:query:duration:)` — DB 자막(SubtitleCue) 정확 매칭 → transcript 문자 오프셋 비율 추정으로 재생 시간 반환
  - `LibraryReducer.playSearchMatch` — 해당 시간으로 플레이어를 열고 재생 (v2.9.1의 initialSeekTime 경유)
  - 그리드/목록 셀 스니펫을 클릭 가능한 버튼으로 변경 (재생 아이콘 + 하이라이트, 호버 포인터)
- 전역 검색 자체(FTS5 `video_fts`, `SearchService.search`, searchResults→스니펫 표시)는 기존에 이미 구현·활성화되어 있어 보강만 진행

### Verification
- `./build_and_run.sh debug macos --no-launch` ✅ (12.73s)
- `swift test` ✅ 76/76 (0 failures)

### Phase B — 플레이어 고도화
- **T-1010**: `MPVClient` 재생 속도(`speed`) + A-B 반복(`ab-loop-a/b/off`) 명령 추가
- **T-1011**: `PlayerReducer` 재생 속도(0.75/1.0/1.25/1.5/2.0x)·A-B 구간·재생 목록(큐) State/Action 추가
  - `setQueue`/`playNext`/`playPrevious` — 보관함 필터 목록 기준 현재 영상부터 연속 재생
  - `loadVideo` 시 A-B 마커 리셋 (속도는 유지)
- **T-1012**: `PlayerView` 컨트롤바 확장
  - 속도 메뉴 버튼, A→B→해제 3단계 토글 버튼(활성 시 accent 표시), 이전/다음 버튼(비활성 상태 반영)
  - `onChange(playbackRate/aLoop/bLoop)` → mpv 실시간 반영
- **보관함 연동**: `openFile` 시 `filteredItems` 기준 현재 영상부터의 재생 목록을 `userInfo["queue"]`로 전달, `AppDelegate.openPlayerWindow`가 큐 설정

### Phase B-2 — 플레이어 UX 개선 (A-B 반복/재생 목록)
- **A-B 반복 UX**: 3단계 토글(A→A-B→✕)을 `시작점(A)`·`끝점(B)` 2버튼으로 분리
  - A: 현재 위치를 시작점으로 설정/갱신 (accent 활성 + 시간 표시 `A 1:23`)
  - B: A 설정 후 활성화, 누르면 끝점 설정 → A~B 반복 시작, 다시 누르면 해제
  - 타임라인(슬라이더)에 A~B 반복 구간을 accent 색 바(오버레이)로 시각화
- **재생 목록 패널**: 컨트롤바 `list.bullet` 버튼으로 우측 패널 토글
  - 보관함에서 연 목록을 보여주고 현재 재생 하이라이트, 항목 클릭 시 즉시 재생(`playAtQueue`)
  - 이전/다음 버튼 툴팁에 영상 제목 표시 (`다음: …`), 빈 목록이면 안내 문구
- **PlayerWindow**: 플레이어 창 ESC로 닫기 (전체화면이면 ESC=전체화면 종료)

### Verification
- `./build_and_run.sh debug macos --no-launch` ✅ (14.17s)
- `swift test` ✅ 76/76 (0 failures)

### Phase C — 홈 화면 위젯 (WidgetKit) → **진행하지 않음** ⛔
- **T-1020**: `TubeKeepWidget` executableTarget 추가 + `build-macos.sh`가 `Contents/PlugIns/TubeKeepWidget.appex` 조립·서명
  - App Group `group.com.tubekeep` entitlement를 앱·위젯 양쪽에 적용 (ad-hoc 서명)
  - 앱이 그룹 컨테이너 UserDefaults에 다운로드 상태 스냅샷(`widget_snapshot`) 기록
- **T-1021**: `DownloadStatus` 위젯 (small/medium)
  - 진행 중 항목(제목/진행률/속도), 대기 수, 최근 완료 표시
  - TimelineProvider가 1분 주기로 스냅샷 갱신, 완료 시 `WidgetCenter.reloadTimelines`로 즉시 반영
- **결정 (2026-08-06)**: 구현은 완료했으나 ad-hoc 서명 환경에서 macOS 위젯 갤러리 등록이 불가(Developer ID 인증서 필요, chronod `extensionsPendingDescriptorRefetch` 확인). 메뉴바 속도 표시로 충분하다고 판단해 **진행하지 않음**으로 확정. 코드는 유지.
- 파일: `Sources/TubeKeepWidget/DownloadStatusWidget.swift`, `Sources/TubeKeep/Services/WidgetSnapshotStore.swift`, `Entitlements/*.entitlements`, `Info-Widget.plist`

### Phase D — 브라우저 통합 (scheme 확장) ✅
- **T-1030**: `tubekeep://` scheme 확장 (`handleGetURLEvent` 재작성)
  - `tubekeep://add?url=<encoded>` — 영상 다운로더 창 열기 + URL 자동 조회
  - `tubekeep://open?id=<videoId>` — 보관함 항목으로 플레이어 열기 (`openLibraryItem`)
  - 기존 bare URL(`tubekeep://youtube.com/...`) 하위호환 유지
- **T-1031**: Safari/Chrome 확장 앱 → **진행하지 않음** (클립보드 감시로 충분)

### v3.0 추가 개선
- **영상 플레이어 창 최소화 버튼** 추가 (styleMask `.miniaturizable` 누락 수정)
- **영상 플레이어 볼륨 컨트롤** — 컨트롤바 우측 스피커 아이콘(음소거 토글) + 볼륨 슬라이더(0~100, 즉시 mpv 반영)
- **썸네일 토글 체크박스화** — 보관함 그리드/목록 상단의 토글을 `checkmark.square`/`square` + "썸네일" 라벨로 변경
- **앱 종료 안전장치** — 마지막 창을 닫아도 앱 유지 (`applicationShouldTerminateAfterLastWindowClosed = false`)
- **위젯 등록 개선** — `Info-Widget.plist`에 `CFBundleSupportedPlatforms`/`DTPlatformName` 추가, `build-macos.sh`에서 `--deep` 서명 제거(위젯 entitlement 보존) + 임베드 바이너리 개별 서명

### 최종 Verification
- `./build_and_run.sh debug macos --no-launch` ✅ (Phase D·볼륨·최소화 빌드 통과)
- `swift test` ✅ 76/76 (0 failures)

## v2.9.1 (2026-08-05) — 타임스탬프/챕터 플레이어 연동 (macOS) ✅

> R4 서브리듀서 분리 회귀 확인 중 발견된 UX 픽스. 플레이어가 닫힌 상태에서 챕터·Q&A 타임스탬프 클릭 시 무동작이던 것을 개선.

### Fixes
- **T-907**: 챕터/Q&A 타임스탬프 클릭 시 내장 플레이어를 열고 해당 시간으로 이동
  - 기존: `.seekToTimestamp`가 `.seekToTime` 알림만 post → **이미 열린 플레이어에만** seek, 닫혀 있으면 무동작
  - 개선: `PlayerItem.initialSeekTime` 추가 → `QnAReducer.seekToTimestamp`가 해당 영상의 `PlayerItem`을 만들어 `openPlayerWindowNotification` post(기존 창 재사용 + 새 창 생성) → `PlayerView.setupPlayer()`가 `MPVClient.seekAfterLoad()`로 **MPV_EVENT_FILE_LOADED 시점에** 정확한 위치 seek
  - `seekToTime` 알림/`QAModels` 확장·PlayerView 리스너 제거 (사용처 없음)

### Verification
- `./build_and_run.sh debug macos --no-launch` ✅ (5.89s)
- `swift test` ✅ 76/76 (0 failures)

## v2.9 (2026-08-05) — 리팩토링 R1~R5 + 테스트 정리 (macOS) ✅

> 기능 동작 변경 없음. 코드 품질·유지보수 목적의 리팩토링. R1~R5 모두 완료.

### Refactoring
- **R1 (T-901)**: `YouTubeDLService`의 죽은 다운로드 경로(`download`/`buildDownloadArgs`/`constructOutputTemplate`, ~110줄) 제거 → 실다운로드는 `DownloadManager` 단일 경로
- **R2 (T-902)**: `AppReducer`의 statusBar 동기화(5회)·addToQueue(2회) 중복 → `syncStatusBar`/`addItemToQueue` 헬퍼 추출. `.home(.addToQueueResponse)`/`.discoverAddToQueue` 재구성 (inout escaping 클로저 제거)
- **R3 (T-903)**: 죽은 코드 제거 — `GeminiError.errorCode`, `YouTubeDLService.checkInstallationStatic`, `DownloadQueueReducer` 빈 `#if DEBUG` + `parseFormats` 자기비교 버그 수정 (`$0.height == $0.height` 항상 true)
- **R5 (T-905)**: 대형 뷰 분해
  - `SettingsView` 1098줄 → 93줄 + `SettingsDownloads/Storage/System/Notifications/AITab` + `SettingsComponents`(SettingsRow/PresetEditorSheet/공용 헬퍼)
  - `MainView` 901줄 → ~195줄 + `AIWindowView`(요약/챕터/마인드맵/Q&A 창) 분리
- **T1 (T-906)**: `DownloadItemTests` 오디오 라벨 기대값 `MP3` → `AAC` 정정 (실제 포맷 m4a/AAC)
- **R4 (T-904)**: `LibraryReducer` 서브리듀서 분리 완료
  - 1차 `fff8efa`: `ReportReducer`·`MindmapReducer` 신규 (Scope 기반, 부모 items 부재 → `LibraryCacheService` 직접 로드), `LibraryReducer+Report/+Mindmap` 제거, `.showSummary`가 `mindmap.resetForVideo`와 merge
  - 2차 `fd74e7f`: `QnAReducer`·`PodcastReducer` 신규 (부모 Action `openQnA`는 `.qna(.open)`+`.showSummary`로, `.showSummary`는 `qna.resetForVideo`와 merge), `LibraryReducer+QnA/+Podcast` 제거, `itemsLoaded`의 `podcastAvailableIds`를 `podcast.setAvailableIds`로 위임, Podcast 요약 팝업 부작용은 부모 `.podcast` case에서 처리
  - 뷰 접근 경로 flat → `store.library.qna/podcast.xxx`, 전송부 `.qna(...)`/`.podcast(...)` 감싸기

### Deferred

### Verification
- `./build_and_run.sh debug macos --no-launch` ✅ (R1~R3 6.25s, R5 12.40s, R4 완료 후 6.92s)
- `swift test` ✅ 76/76 (0 failures) — R4(Report·Mindmap) 후 및 R4(QnA·Podcast) 후 재확인

## v2.8.1 (2026-08-05) — v2.1 공통 규칙 적용 (macOS) ✅

> 개인 프로젝트 원칙(AGENTS.local.md 장 0)을 전제로 공통 `AGENTS.md` v2.1의 macOS 적용분을 도입. 코드 행동 변경은 없고 로깅/검증/문서 인프라 중심.

### Rules (macOS 적용)
- **docs/AI_MODELS.json 추가** — AI 모델 체인(openrouter/free → yTeaser/ax4 → gemini), 캐시 정책(SQLite), macOS perf budget 기록
- **에러코드 E-MAC-** 정렬 — `error_message_ko.json`을 `E-MAC-API-*` / `E-MAC-NET-*` 규격으로 갱신 (참조 스펙, 런타임 `n-XXXX` throw는 유지)
- **DebugLogger 9종 레벨** — `PERF`(성능) + `CACHE`(캐시 히트) 추가 (`DebugLogManager.swift`), `DebugLogView` 색상 추가
  - 플레이어 첫 프레임 → `.PERF` 로그 (`MPVClient.swift` renderFrame)
  - 요약 DB 캐시 히트 → `.CACHE` 로그 + `cost_saved` (`SummarizationService.swift`)
- **scripts/env-expiry-check.sh 추가** — `# expires:` 파싱, 30일 전 WARN/만료 시 ERROR + bd 생성
- **scripts/a11y-dump.sh (macOS 적응) 추가** — `.a11y.txt` + `.storage.json` + `.perf.json` → `docs/screenshots/macos/`
- **AGENTS.local.md 갱신** — 버전 정보 통합(장 8 제거 → 장 19), DebugPanel 레벨 표, AI 모델/에러코드/세션로그 규칙 추가

### Removed Features
- **브라우저 쿠키 기능 제거** — 비공개/연령 제한 영상 접근(`--cookies-from-browser`) 미사용으로 코드에서 전면 삭제 (`SettingsView` 피커, `Settings.cookiesFromBrowser`, `SettingsReducer.setCookiesFromBrowser`, `LanguageService.cookiesArgs`, 모든 yt-dlp args 삽입부). bd `TubeKeep-6mg` 닫음. bd `TubeKeep-5y6`(mpv/MoltenVK) 테스트 완료로 닫음

### Documentation / 前 세션 이관
- `docs/plans/PLAN_v2.8.1_macos.md` + `docs/TODO.md` T-875~T-882
- 채널 다운로더 예상 소요시간(추정식) UI — **경과시간 실시간 갱신 픽스**: `loadTick`/`Timer` 제거 → `TimelineView(.periodic)` + `loadStart` 전달 (bd `TubeKeep-vyy` 닫음)
- 플레이어 전체화면/확대 오류 픽스 이관 — `MPVOpenGLView`(NSOpenGLView 서브클래스, reshape→`openGLContext.update()`) + `MPVClient.attachView(MPVOpenGLView)` (사용자 확인 완료 ✅)

## v2.8.0 (2026-08-02) — 코드 정리 리팩터링 ✅

### Refactoring
- **GeminiService.swift** 생성 — `TaggingService`와 `SummarizationService` 사이의 중복 `queryGemini` 함수를 통합. 4회 재시도 로직 + `GeminiError` enum (요청 한도 초과, API 오류, 응답 없음, 연결 실패, 파싱 실패) 포함
- **Settings.APIKeys** 구조체 추가 + `Settings.loadAPIKeys()` 정적 메서드 — 8곳의 직접 `UserDefaults.standard.string(forKey:)` API 키 읽기 제거 (`LibraryReducer.swift` 7곳, `HomeReducer.swift` 1곳)
- **Settings.loadSettings()** 단일화 — 4개의 중복 `loadSettings()` 정의 제거 (`LibraryReducer.swift`, `SummarizationService.swift`, `PlayerReducer.swift`, `DownloadQueueReducer.swift`에서 각각 복제됨). 5곳의 호출처를 `Settings.loadSettings()`로 통일. 추가로 `YouTubeDLService.swift`, `PodcastService.swift`, `UploadOrderService.swift`, `LanguageService.swift` (2곳), `DownloadItem.swift` (2곳), `AppReducer.swift`, `AppDelegate.swift`, `DownloadQueueView.swift`, `PlayerReducer.swift`에서 인라인 UserDefaults/JSONDecode 패턴 제거
- **DebugLogManager 강제 사용화** — `AppDelegate.swift` (7곳), `WhisperService.swift`, `ChannelUpdateService.swift`, `MPVClient.swift` (4곳), `SettingsReducer.swift` (2곳), `LibraryReducer.swift` (1곳) 총 18개의 `print()` 호출 제거. AGENTS.md Rule 8 준수
- **DatabaseManager 정리** — 죽은 코드 제거 (`QnAEntry` struct + 3개 미사용 메서드). `saveQAHistory`에서 `defer` 패턴 + 일관된 로깅 사용
- **LibraryReducer 분해** — 4개 기능 섹션을 별도 파일로 추출:
  - `LibraryReducer+Report.swift` (28줄) — Report/Digest 액션 처리
  - `LibraryReducer+Mindmap.swift` (63줄) — Mindmap 액션 처리
  - `LibraryReducer+QnA.swift` (88줄) — Q&A 액션 처리
  - `LibraryReducer+Podcast.swift` (110줄) — Podcast 액션 처리
  - 메인 파일: 1226 → 989줄 (`Self.handleXxxAction(state: &state, action: action)` 디스패치 패턴)

### Error Code System (AGENTS v1.9)
- `GeminiError`에 `errorCode` 프로퍼티 추가 (`E-COM-API-1001`, `E-COM-NET-1006`, 등 8가지 코드)
- `error_message_ko.json` 생성 — GeminiError 코드별 사용자 메시지 매핑

### Bug Fixes
- **AI 요약 정보 갱신 안 됨**: Home 화면에서 새 URL 입력 시 `summaryText`가 초기화되지 않아 `toggleSummaryPopover`가 이전 영상 요약을 그대로 표시하던 문제 수정
  - `HomeReducer.swift`: `.infoResponse`, `.infoFailed`, `startFetch()`, `.resetInfo` 모두에서 `summaryText`, `summaryProvider`, `showSummaryPopover`, `summaryLoading` 초기화 추가
- **AI 창에 이전 영상 정보 표시 (레이스컨디션)**: 늦게 도착한 이전 영상의 API 응답이 현재 영상 요약을 덮어쓰던 문제 수정
  - `LibraryReducer.swift`: `.summaryResult`/`.summaryFailed`/`.summaryProgressUpdate`에 `videoId == state.librarySummaryVideoId` 가드 추가
  - `HomeReducer.swift`: `summaryLoaded(videoId:text:provider:)`, `summaryFailed(videoId:error:)` 시그니처로 videoId 전달 + `videoId == state.videoInfo?.id` 가드
  - `LibraryReducer.swift` Discover: `discoverSummaryLoaded(videoId:text:provider:)`, `discoverSummaryFailed(videoId:error:)` + `videoId == state.discoverSummaryVideoId` 가드
- **AI 창 썸네일/아바타가 영상 전환 시 갱신 안 됨**: `CachedThumbnailView`/`CachedAvatarView`의 `@State image`가 뷰 재사용 시 초기화되지 않아 이전 영상 이미지가 남던 문제 수정
  - `Views/CachedImageViews.swift`: `.id()` 대신 `.onChange(of: videoId/channelId) { image = nil; Task { reload } }` + `.task`로 교체
- **채널 다운로더 창 지연**: 미구독 채널에서 창을 열기 전 `fetchChannelInfo`(네트워크)를 기다려 창이 늦게 뜨던 문제 수정
  - `LibraryReducer.swift` `.openChannelDownload`: 창을 즉시 열고, 채널 정보 조회는 `ChannelDownloaderView`가 백그라운드에서 처리
- **채널 다운로더 다중 창**: 창을 로컬 변수로만 생성해 속성에 저장하지 않아 닫은 후 새 창이 반복 생성되던 문제 수정
  - `AppDelegate.swift`: `channelDownloaderWindow` 속성으로 창을 보관·재사용

### Infrastructure

### Testing
- 74/76 테스트 통과 (2개 사전 존재 실패: `DownloadItemTests` — `optionsLabel`이 "AAC"를 반환하지만 테스트는 "MP3" 기대 — 리팩터링과 무관)

---

## v2.7.7 (2026-07-28) — 오디오 누락 버그 수정 + DebugPanel v1.7 ✅

### Bug Fixes
- **다운로드 시 오디오 누락 수정**: `parseFormats()`에서 같은 해상도의 combined 포맷과 video-only 포맷이 경합할 때 filesize 기준으로만 선택하여 combined(오디오 있음)가 video-only에 덮어써지던 문제 수정
  - `YouTubeDLService.swift` `parseFormats()`: combined 포맷에 우선권 부여 — 기존 entry가 combined면 교체하지 않고, 새 포맷이 combined면 기존 video-only를 교체
- **`bestaudio[ext=m4a]` → `bestaudio`**: `[ext=m4a]` 필터가 YouTube의 Opus/webm 오디오를 배제하여 `+` 병합 실패를 유발하던 문제 수정
  - `YouTubeDLService.swift` `buildDownloadArgs()`: `[ext=m4a]` 제거
  - `DownloadManager.swift` `buildDownloadArgs()`: `[ext=m4a]` 제거
  - `--merge-output-format mp4`가 ffmpeg로 mp4 리먹싱 보장
- **채널 다운로더 오디오 누락 근본 수정**: `buildDownloadArgs()`에서 복합 포맷 선택자(`best[height<=360]/best`)가 `id.hasPrefix("best")` 분기에 걸려 `bestvideo+bestaudio`로 잘못 래핑되던 문제 수정
  - id에 `/` 또는 `+`가 포함된 경우 `bestvideo+bestaudio` 래핑을 건너뜀
  - `DownloadManager.swift:236` + `YouTubeDLService.swift:293-301` 동시 수정

### DebugPanel v1.7 (AGENTS.md 표준)
- **`DebugLogLevel` enum 7종**: ACTION, API→, API←, INFO, WARN, ERROR, SYSTEM
- **`DebugLogEntry` struct**: timestamp + level + platform + category + message + meta + `formatted`
- **`push()` / `clear()` / `formatForAgent()`**: 표준화된 로그 포맷 + 에이전트 붙여넣기용 출력
- **`maskSecrets()`**: 토큰/키 마스킹 + 500자 truncation
- **`maxLogs = 5000`**: FIFO 자동 정리
- **NSWindow 표준**: 600×320 화면 중앙, 400→2000 리사이즈, `.floating + 100`, `isReleasedWhenClosed=false`, 재사용 패턴
- **색상 표준**: ERROR=빨강, WARN=노랑, API→=파랑, API←=초록, SYSTEM=보라, INFO=회색, ACTION=흰색
- **📌 자동 스크롤 토글**: ON/OFF 토글 + 드래그 시 2초 일시정지
- **줄 선택**: 클릭=1줄, Shift+클릭=범위, Cmd+클릭=개별 토글
- **선택 복사 / 전체 복사 / 클리어**: NSPasteboard 연동

### Infrastructure
- **scripts/build-macos.sh** 생성 — build_and_run.sh에서 빌드 로직 분리
- **build_and_run.sh** → v1.7 멀티 플랫폼 디스패처 (debug/release + macos/ios/android/web)
- **Package.swift**: `.define("DEBUG", .when(configuration: .debug))` — release에서 DebugPanel 컴파일 타임 제거
- **Mock/DEBUG 테스트 코드 전면 제거**: LibrarySidebarView, DownloadQueueView, BatchDownloadView, HomeView, StatusBarManager, AppDelegate, AppReducer, HomeReducer, DownloadQueueReducer — 모든 mock 버튼/메뉴/액션 삭제
- **beads skill 파일 삭제**: `.agents/skills/beads/SKILL.md`, `agents/openai.yaml`
- **`.codex/hooks.json` 삭제**, `.codex/config.toml` 정리
- **AGENTS.md → 전역 설치**: `bd setup codex --global`로 `~/.codex/AGENTS.md`로 이동, 프로젝트에서는 제거
- **AGENTS.local.md**: v1.7 DebugPanel 전체 기능표 + build workflow + v2.7.7 (build 18) 동기화
- **Info.plist**: v2.7.7 (build 18)

## v2.7.6 (2026-07-25) — 랜딩 페이지 + Buy Me a Coffee ✅

### Features
- **GitHub Pages 랜딩 페이지** (`docs/index.html`, `docs/style.css`, `docs/app-icon.png`): 앱 소개 + 기능 카드 + 다운로드 링크 + Buy Me a Coffee
- **Buy Me a Coffee 후원 링크** (`StatusBarManager.swift`, `AppDelegate.swift`): 메뉴바 "☕ 후원하기" 메뉴 항목 추가, `borasarang` 계정 연결

### Fixes
- **상태바 정렬 통일**: idle/완료/상태표시 모두 `.right` 정렬로 변경 — 아이콘(좌) + 텍스트(우) 균형 개선

## v2.7.5 (2026-07-25) — 자체 업데이트 ✅

### Features
- **UpdateChecker** (`Services/UpdateChecker.swift`): `appcast.json` 기반 버전 체크, GitHub Releases 다운로드 URL 오픈, "이 버전 건너뛰기" 저장
- **앱 시작 시 업데이트 확인** (`AppDelegate.swift`): 3초 후 백그라운드 체크 → alert 표시
- **appcast.json**: 최신 버전 메타데이터 (GitHub raw 호스팅)

## v2.7.4 (2026-07-25) — 코드 서명 + Notarization ✅

### Features
- **codesign.sh** (`Tools/codesign.sh`): Developer ID 서명 → Notarization 제출 → Ticket Stapling → DMG 서명 자동화
- **Makefile**: `codesign`/`notarize`/`sign-only`/`release-signed` 타겟 추가

## v2.7.3 (2026-07-25) — DMG 배포 + GitHub Releases ✅

### Features
- **DMG 생성 스크립트** (`Tools/create_dmg.sh`): TubeKeep.app + Applications symlink 포함, Finder 레이아웃 설정, UDZO 압축
- **Makefile release 개선**: `release`(빌드→DMG), `release-upload`(gh release), `release-dmg`(DMG만) 타겟
- **build_and_run.sh**: `--no-launch` 플래그 추가 (release 빌드용)

### Bug Fixes
- **DebugLogManager**: `#if DEBUG` 제거 — release 빌드 시 심볼 누락으로 빌드 실패하던 문제 수정

### Features
- **설정 4탭 → 5탭** (`SettingsView.swift`): 다운로드·저장·알림 신규·시스템·AI 설정으로 재구성; "채널 업데이트 알림"을 "알림 신규" 탭으로 이동, 시스템 탭의 11개 혼합 항목을 적절한 탭에 재배치
- **"채널 업데이트 알림" → "채널 업데이트 확인"** (`ChannelUpdateService.swift`): OFF 시 타이머/API/알림 완전 중단 (Combine observer 패턴)
- **도구 모음 드롭다운 통합** (`MainView.swift`): 3개 툴바 버튼 → `Menu("영상 다운로드")` 드롭다운으로 통합

### Bug Fixes
- **상태바 큐 항목 비활성화** (`StatusBarManager.swift`): `action: nil`로 생성한 메뉴 아이템이 시스템에 의해 비활성화/흐리게(faded) 표시되던 문제 — `#selector(queueItemNoop)` + `target: self`로 수정, 다운로드 상태와 무관하게 항상 표시
- **채널 체크박스 선택 미초기화** (`ChannelContentView.swift`): `addSelectedToQueue()`에서 다운로드 후 `selectedIDs`를 비우지 않아 다운로드 완료 후에도 체크 표시가 유지되던 문제; 채널 전환 시 이전 채널의 `selectedIDs`가 유지되던 문제를 `.onChange(of: channel?.id)`로 수정

### Performance
- **첫 재생 지연 단축** (`PlayerView.swift`): `needsTranscoding()`에서 ffprobe `Process`+`waitUntilExit()` 호출(프로세스 생성/파이썬 init/파일 I/O 5~10초 소요)을 `AVURLAsset.loadTracks`+`load(.formatDescriptions)`로 대체; `codecCache`를 `UserDefaults`에 저장하여 앱 재시작에도 코덱 캐시 유지

### Infrastructure
- **Info.plist**: v2.7.2 (build 13)

## v2.7.1 (2026-07-21) — Critical Bug Fixes + 성능 개선 ✅

### Bug Fixes (Critical)
- **Playlist URL 초기화** (`HomeReducer.swift`): `infoResponse`에서 `state.urlString` 클리어 시점을 playlist 체크 이후로 이동 — 재생목록 URL이 항상 빈 문자열로 전달되던 버그 수정
- **False 설정 복원** (`AppReducer.swift`): `playSoundOnComplete=false`, `clipboardMonitoring=false`가 앱 재시작 시 무시되던 버그 수정 — `if` 조건을 `!settings.playSoundOnComplete`으로 변경
- **Actor 차단 해소** (`SummarizationService.swift`): `process.waitUntilExit()`가 actor 협력 스레드를 블로킹하던 문제 — `terminationHandler` 기반 정적 메서드 `runProcess()`로 교체
- **Data race** (`BookmarkManager.swift`): `nonisolated(unsafe) var activeURLs`에 lock 없이 동시 접근 — `OSAllocatedUnfairLock`으로 동기화
- **API 키 노출** (`MindmapService.swift`): `print("[Mindmap] ❌ API 키: ...")`이 릴리스 빌드에서 콘솔에 출력 — `log()`로 교체, `print()` 제거
- **하드코딩 API 키** (`Constants.swift`): `defaultAX4APIKey`가 소스 코드에 포함 — 빈 문자열로 변경
- **SRT 숫자 텍스트 누락** (`PlayerReducer.swift`, `WhisperService.swift`, `SummarizationService.swift`): `Int($0) == nil` 필터가 숫자로만 된 자막 텍스트를 잘못 제거 — `seenTiming` 플래그로 SRT 인덱스 번호만 필터

### Bug Fixes (High)
- **이중 컨트롤** (`NSPlayerView.swift`): `controlsStyle = .default`로 AVPlayer 기본 컨트롤 + SwiftUI 커스텀 컨트롤바가 동시에 표시 — `.none`으로 변경
- **영상 재생 지연** (`PlayerView.swift`): `setupPlayer()`에서 `needsTranscoding()` 호출이 `process.waitUntilExit()`로 메인 스레드 1~5초 차단 — `Task { }`로 비동기 분리하여 즉시 재생
- **죽은 코드** (`NSPlayerView.swift`): 미사용 `playerLayer` 변수 제거

### Infrastructure
- **Info.plist**: v2.7.1 (build 12)

## v2.7.0 (2026-07-20) — 시스템 언어 + 쿠키 인증 + Whisper AI 자막 + 프리셋 + 히스토리 ✅

### New Features
- **시스템 언어 기반 동적 전환**: 하드코딩된 한국어(`"en,ko"`, `"ko-KR"`) → `Locale.current` 기반 자동 전환
  - 자막 다운로드 언어 (`--sub-langs`), TTS 음성, AI 프롬프트 언어가 시스템 언어를 따라감
  - `LanguageService.swift` 신규 — 언어별 Edge TTS 음성 맵핑 테이블 포함
  - Settings에 자막 언어 override 옵션 제공 (자동/한국어/영어/일본어)
- **브라우저 쿠키 인증**: `--cookies-from-browser` 플래그로 비공개/연령 제한/멤버십 영상 접근
  - Safari / Chrome / Brave / Edge / Firefox 선택 가능
  - 모든 yt-dlp 호출(info fetch, subtitle, streaming URL, download)에 쿠키 전파
- **AI 자막 생성 (Whisper CoreML)**: yt-dlp 자막이 없는 영상도 음성 인식으로 자동 자막 생성
  - WhisperKit SPM 기반, Apple Silicon CoreML 최적화
  - 모델(~500MB)은 백그라운드 다운로드 — 다운로드 중에도 앱 사용 가능
  - Settings UI: 토글 + 모델 다운로드 버튼 + 진행률(속도/ETA/남은시간) + 상태 표시
  - 플레이어와 요약 서비스 모두 Whisper fallback 연결
- **다운로드 프리셋 / Smart Mode**: 자주 쓰는 설정을 프리셋으로 저장 → 1클릭 다운로드
  - 기본 프리셋 3개: "고품질 (4K)", "기본 (1080p)", "오디오만"
  - Smart Mode ON: URL 입력 → 정보 조회 → 프리셋 자동 적용 → 큐 바로 추가
  - Settings 저장 탭에서 프리셋 추가/편집/삭제
- **다운로드 히스토리 (DB)**: 모든 다운로드 완료 내역을 SQLite에 영구 기록
  - download_history 테이블: video_id, title, channel, url, format, resolution, file_size, file_path, downloaded_at, status
  - HistoryView: 테이블 뷰 + 검색 + 날짜별 필터 + 우클릭 메뉴

### UI Changes
- SettingsView 시스템 탭 — "브라우저 쿠키" Picker 추가
- SettingsView AI 탭 — "AI 자막 생성 (Whisper)" 섹션 추가 (설명 + 토글 + 모델 다운로드 UI)
- SettingsView 저장 탭 — "다운로드 프리셋" 섹션 추가 (목록 + 추가/편집/삭제)
- VideoDownloadView — Smart Mode 토글 + 프리셋 Picker
- LibrarySidebarView — "다운로드 히스토리" 항목 추가
- 앱 전체 토스트 알림 — Whisper 모델 다운로드 진행률/완료/실패 표시

### Infrastructure
- **신규 파일 7개**: `Helpers/LanguageService.swift`, `Services/WhisperService.swift`, `Models/DownloadPreset.swift`, `Features/Library/HistoryView.swift`, `Components/ToastView.swift`, `Components/WhisperDownloadView.swift`
- **설정 6개 추가**: `subtitleLanguageOverride`, `cookiesFromBrowser`, `enableAISubtitles`, `whisperModelDownloaded`, `presets`, `smartMode`, `activePresetId`
- **DB 테이블 1개 추가**: `download_history`
- **Info.plist**: v2.7.0 (build 11)

## v2.6.2 (2026-07-20) — 스레드 안정성 + 메뉴바 드롭메뉴 개선 ✅

### Bug Fixes
- **다운로드 데이터 레이스 크래시 수정**: `DownloadManager`의 `settings`/`storageDirectory`/`filenameTemplate`이 Lock 없이 여러 스레드에서 접근되던 문제 수정
  - `OSAllocatedUnfairLock`으로 `ManagerState` 전체 보호
  - `startDownload()` 진입 시 Lock에서 값 복사 후 사용 → 이후 Lock 불필요
  - `buildDownloadArgs()`/`constructOutputTemplate()`에 파라미터 전달 방식으로 변경
- **`DateFormatter` 스레드 안전성 수정**: `#if DEBUG` `timestamp()` 함수가 매 호출마다 새 `DateFormatter`를 생성하여 ICU 내부 상태가 손상되는 힙 코럽션 크래시 수정
  - 정적 `timestampFormatter` + `OSAllocatedUnfairLock`으로 변경
- **`pausedItems` Lock 누락 수정**: `Set<UUID>`에 대한 모든 접근을 `stateLock`으로 보호
- **Mock 테스트 서브메뉴 비활성화 수정**: `NSMenuItem`에 `target = self` 누락으로 DEBUG 메뉴 항목이 회색 처리되어 클릭 불가능했던 문제 수정 (`StatusBarManager.swift`)
- **TTS 엔진 기본값 변경**: `macOS 내장` → `Edge TTS` (Settings.swift, SettingsReducer.swift, PodcastService.swift 3군데)

### UI Changes
- **메뉴바 드롭메뉴 `NSView` 기반으로 전면 재작성**: `attributedTitle` + `NSTextTab` 방식의 오른쪽 정렬이 NSMenu right inset(~14pt)을 제어할 수 없어 빈 공간이 발생하던 문제를 `NSMenuItem.view`(커스텀 NSView + 두 개 NSTextField) 방식으로 교체
  - `menuTabStopLocation`/`attributedMenuTitle()` 제거 → `makeQueueMenuItemView()` + `updateLabel()` 추가
  - `menuLeftPadding: CGFloat = 19`, `menuRightPadding: CGFloat = 14` — 일반 메뉴 항목과 동일한 좌우 여백
  - `menuItemViewWidth: CGFloat = 187` — 기존 280pt에서 1/3 축소
- **드롭메뉴 텍스트 변경**: "다운로드 중" → "다운로드 속도", "진행 상태" value = "완료/전체", "남은 시간" 유지
- **메뉴바 상태 텍스트 변경**: "완1/4" → "진행 1/4"

### Infrastructure
- **Info.plist**: v2.6.2 (build 10)
- **AGENTS.md**: `코드 수정 후 반드시 build_and_run.sh 실행` 규칙 추가

## v2.6.1 (2026-07-20) — H.264 다운로드 + 플레이어 개선 ✅

### New Features
- **H.264 우선 다운로드**: yt-dlp `-f`에 `[ext=mp4][vcodec^=avc1]` 필터 추가 → 새로 받는 영상은 변환 불필요
- **트랜스코딩 캐시**: SHA256 해시 기반 캐싱 (`~/Library/Caches/com.tubekeep/transcoded/`) → 같은 파일 재변환 방지
- **변환 진행률 + ETA**: ffmpeg `-progress pipe:1` 파싱 → determinate ProgressBar + "% 변환 중... (남은 시간: XX:XX)"
- **플레이어 컨트롤 오버레이**: 호버 시에만 나타나는 하단 컨트롤바 (재생/정지, 시크 슬라이더, 시간 표시, 3초 후 자동 숨김)
- **자막 언어 우선순위**: 한국어(`.ko.`) → 영어(`.en.`) 순서로 정렬

### UI Changes
- **자막 오버레이 기본값 OFF**: 영상만 먼저 보여주고, 싱글클릭 시 오버레이 표시
- **자막 패널 자동 스크롤**: 현재 재생 위치의 자막으로 자동 포커스
- **기본 해상도**: 480p → 360p (Constants.defaultResolution)

### Bug Fixes
- **전체화면 미동작**: `WindowAccessor` `[self]` 캡처로 window 참조 유실 문제 수정
- **영문 자막 우선 표시**: 파일 정렬 없이 `contentsOfDirectory` 순회로 영어가 먼저 나오는 문제 수정
- **다운로드 실패 오진**: `--embed-thumbnail`로 생성된 .webp/.png 섬네일 경로가 `after_move:filepath`를 오염시켜 .mp4가 정상 생성됐음에도 실패로 표시되는 문제 수정
  - after_move 경로가 .mp4인지 검증 후, 아니면 출력 디렉토리에서 `{videoId}.mp4` 직접 스캔 fallback
- **H.264 필터 누락**: `DownloadManager.buildDownloadArgs()`에 `[ext=mp4][vcodec^=avc1]` 포맷 필터가 없어 360p 다운로드도 AV1/VP9로 받아 변환 발생하던 문제 수정

### Infrastructure
- **Info.plist**: v2.6.1 (build 9)

## v2.6.0 (2026-07-20) — 자체 비디오 플레이어 + 플레이어 모드 설정 ✅

### New Features
- **자체 비디오 플레이어**: AVKit 기반 별도 창 플레이어 (960×640 고정)
  - `AVPlayerView` 래퍼 — 재생/일시정지/볼륨/타임라인 기본 컨트롤
  - 우측 자막 패널 (320pt, toggle) — 전체 자막 리스트 + 현재 위치 하이라이트
  - 비디오 위 자막 오버레이 (toggle) — 시간 동기화 자막 표시
  - 툴바: 자막 오버레이 토글 / 자막 패널 토글 / Pin(최상위 고정) / Close
  - `.seekToTime` notification 구독 — Q&A 타임스탬프 클릭 시 seek
- **플레이어 모드 설정**: 시스템 탭 "비디오 플레이어" picker
  - `자체 플레이어` (기본값) — "열기" 버튼이 TubeKeep 내장 플레이어 실행
  - `기본 연결 프로그램` — "열기" 버튼이 `NSWorkspace.shared.open` (기존 동작)
- **Discover 미리보기**: 미다운로드 영상 hover 시 "미리보기" 버튼
  - `yt-dlp -f best --get-url` → 스트리밍 URL → 자체 플레이어로 재생
- **자막 시간 동기화**: yt-dlp VTT/SRT 다운로드 → 타임스탬프 보존 파싱 → 오버레이/패널

### Infrastructure
- **신규 6개 파일**: Features/Player/ 아래 PlayerItem, PlayerReducer, NSPlayerView, SubtitleOverlay, SubtitlePanel, PlayerView
- **YouTubeDLService.fetchStreamingURL()** — `--get-url` 스트리밍 URL 조회
- **YouTubeDLService.fetchSubtitles()** — 시간 동기화 자막 다운로드/파싱
- **PlayerMode enum**: Settings에 `builtIn` / `systemDefault` 케이스
- **Info.plist**: v2.6.0 (build 8)

## v2.5.6 (2026-07-19) — 마이그레이션 + 최종 테스트 ✅ 완료

### Testing
- **자동화 테스트 21개 추가**: MindmapNodeTests(8), QAModelTests(6), PodcastModelTests(7)
  - 샘플 JSON 테스트 데이터 기반 모델 인코딩/디코딩 검증
  - MindmapNode UUID 버그 수정 검증 (id 없는 JSON 디코딩)
- **총 76개 테스트 전원 통과** (기존 55 + 신규 21)
- **release 빌드 성공** (1개 기존 경고, TTSService @preconcurrency)
- **수동 테스트 패스**: 배포 전 최종 검증에서 수행 예정

### Infrastructure
- **Info.plist**: v2.5.6 (build 7)
- **MindmapNode Equatable**: id 무시하도록 custom `==` 구현 (label/children만 비교)

## v2.5.5 (2026-07-19) — AI 창 UI 통합 + 마인드맵 보기 ✅ 완료

### New Features
- **마인드맵 보기**: AI 창 내 expandable/collapsible 트리 뷰 (MindmapTreeView, MindmapNodeView)
- **마인드맵 생성/캐싱**: OpenRouter API → JSON 파싱 → DB 저장, showSummary 시 자동 로드

### UI Changes
- **AI 요약 팝업 → AIWindowView**: summary+chapters(좌) / mindmap+Q&A(우) 좌우 split 레이아웃
- **컨텍스트 메뉴 통합**: "AI 요약정보 보기" / "AI 팟캐스트" / "AI Q&A" 3개 → "AI 기능" 단일 메뉴 (sparkles icon)
- **QAInputBar 이동**: AIWindowView 하단 → qnaSection 상단 (title 아래)
- **팟캐스트 시간 표시**: 플레이 버튼 오른쪽 → 왼쪽으로 이동
- **요약 로딩 오버레이 다크모드 대응**: Color.white → .regularMaterial
- **QAInputBar 자동 포커스 방지**: @FocusState optional nil + AppDelegate makeFirstResponder(nil)
- **미사용 코드 제거**: MindmapButtonView 삭제

### Bug Fixes
- **MindmapNode UUID 디코딩 오류 수정**: JSON에 id 필드 없어 파싱 실패 → CodingKeys에서 id 제외, init(from:)에서 UUID() 기본값

### Infrastructure
- **MindmapService.swift**: 마인드맵 생성/파싱/DB 저장 서비스
- **MindmapModels.swift**: MindmapNode 모델 (재귀적 Codable)
- **LibraryReducer mindmap 액션**: generateMindmap / mindmapResult / mindmapFailed / toggleMindmap

## v2.5.4 (2026-07-19) — 마인드맵 생성 (v2.5.5와 통합)

v2.5.4의 마인드맵 기능은 v2.5.5에서 AI 창 UI 통합과 함께 구현됨.
자세한 내용은 v2.5.5 항목 참조.

## v2.5.3 (2026-07-19) — 트랜스크립트 Q&A ✅ 완료

### New Features
- **트랜스크립트 Q&A**: 영상 자막 기반 질문/답변 기능
  - QAService: OpenRouter → yTeaser → A.X 4.0 → Gemini 폴백 체인
  - qna_history DB 테이블: 질문/답변/타임스탬프 저장/로드
  - 타임스탬프 클릭 → 영상 재생 위치 이동
- **QAView UI**: 질문 입력 → 답변 표시 + 히스토리 목록

### Infrastructure
- **QAService.swift**: Q&A 생성 서비스 (actor, 폴백 체인)
- **qna_history 테이블**: DatabaseManager에 qna_history CRUD 추가
- **LibraryReducer Q&A 액션**: askQuestion / questionResult / questionFailed / clearQAHistory

## v2.5.2 (2026-07-18) — AI 팟캐스트 생성 (macOS 내장 TTS) ✅ 완료

### New Features
- **AI 팟캐스트 생성**: 자막을 분석하여 2인 대화형 팟캐스트를 자동 생성
  - 대화 스크립트 생성: 기존 LLM 폴백 체인 활용 (OpenRouter → yTeaser → A.X 4.0 → Gemini)
  - TTS 변환: macOS 내장 AVSpeechSynthesizer 사용 (완전 무료, 오프라인)
  - 한국어 음성 지원 (Yuna, Siwoo 등)
  - 팟캐스트 생성/재생/삭제 기능

### UI Changes
- **요약 팝업에 팟캐스트 컨트롤 추가**: 재생/일시정지/정지 버튼 + 진행 바
- **컨텍스트 메뉴 팟캐스트 항목**: 팟캐스트 만들기/듣기/삭제

### Infrastructure
- **PodcastService.swift**: 팟캐스트 생성 서비스 (actor)
- **TTSService**: AVSpeechSynthesizer 래퍼
- **팟캐스트 저장 위치**: `~/Documents/TubeKeep/Podcasts/{videoId}/`
- **DB 연동**: `podcast_path` 컬럼 활용

## v2.5.1 (2026-07-18) — AI 요약 + 챕터 생성 ✅ 완료

### New Features
- **챕터 생성**: AI 요약 시 자동으로 챕터(구간) 정보 생성
  - SummaryResult.chapters 필드 추가
  - 모든 LLM 서비스(OpenRouter/yTeaser/A.X 4.0/Gemini) 프롬프트에 챕터 형식 추가
  - 챕터 응답 파싱 로직 (타임스탬프 + 제목)

### UI Changes
- **LibraryGridView 챕터 표시**: 썸네일 하단 챕터 리스트
- **LibraryListView 챕터 표시**: 목록 행에 챕터 표시

### Infrastructure
- **ChapterInfo 모델**: Codable, Identifiable (startTime, title, endTime)
- **DB 챕터 저장**: DatabaseManager에 chapters 컬럼 저장/로드

## v2.5.0 (2026-07-18) — SQLite DB 구축 + 자막 DB 저장 + AI 요약 캐싱

### New Features
- **AI 요약 DB 캐싱**: 요청 시 SQLite에서 기존 요약 확인 → 있으면 API 호출 없이 즉시 표시
  - `summarizeVideo()` API 폴백 체인 진입 전 DB 캐시 확인
  - `.showSummary` 시 `item.summary` 먼저 확인
  - 요약 생성 후 `DatabaseManager.updateSummary()`로 SQLite 저장
- **자막 가용성 DB 체크**: `hasSubtitles()`가 파일시스템 대신 SQLite에서 transcript 존재 여부 확인

### Bug Fixes
- **키보드 단축키 한글 레이아웃 호환**: `event.charactersIgnoringModifiers` → `event.keyCode`로 변경
  - 한글 키보드에서 `c`→`ㅍ`, `v`→`ㅇ` 등으로 매핑되어 단축키 미동작
  - `keyCode`는 레이어와 관계없이 고정 (0=A, 7=X, 8=C, 9=V, 49=,)
- **디버그 로그 초기화 시점**: `DebugLogManager.shared`를 `applicationDidFinishLaunching` 즉시 초기화

### Infrastructure
- **자막 파일 → DB 저장으로 전환**: `.vtt`/`.srt` 파일을 디스크에 저장하지 않고 SQLite DB에 저장
  - `LibraryReducer.downloadSubtitles`: 임시 디렉토리에 다운로드 → 파싱 → DB 저장 → 파일 삭제
  - `DownloadManager`: 비디오 다운로드 시 자막도 DB 저장 + 디스크 파일 정리
  - `SummarizationService.parseVTT`/`parseSRT`를 `static func`으로 변경하여 공유
- **기존 자막 파일 마이그레이션**: 디스크에 남아있던 17개 `.vtt` 파일을 DB에 저장 후 삭제

## v2.4.0 (2026-07-16) — 기술부채 해소 + SwiftData 전환 + A.X 4.0 통합

**macOS 14+ 전용** | Swift 6.3 | SPM 6.2

### New Features
- **SKT A.X 4.0 AI 요약/태깅 통합**: 한국어 특화 LLM으로 요약/태깅 품질 향상
  - A.X 4.0 → yTeaser → Gemini 3단계 무료→유료 폴백 체인
  - 설정에서 A.X 4.0 API 키 관리 (공개 키 기본값 제공)
  - AI 요약 설정 탭 분리 (A.X 4.0 / Gemini)

### Breaking Changes
- **최소 macOS 버전 14.0으로 상향**: SwiftData 지원을 위한 변경 (이전: macOS 13+)

### Infrastructure
- **SwiftData 마이그레이션**: `LibraryItem`, `SubscribedChannel`을 UserDefaults → SwiftData `@Model` 클래스로 전환
  - `PersistenceController` 싱글톤 추가 (`ModelContainer` 관리)
  - `LibraryCacheService`를 actor → `@MainActor` 클래스로 변경, SwiftData 기반 CRUD로 재작성
  - `SubscribedChannel.loadAll()`/`saveAll()` → SwiftData `FetchDescriptor` 기반으로 변경
  - UserDefaults → SwiftData 자동 마이그레이션 (`SwiftDataMigration.migrateIfNeeded`)
- **AppDelegate 분리**: 1056줄 → 536줄 (49% 감소)
  - `StatusBarManager.swift`: 상태바 + 메뉴 + 큐 요약 추출
  - `ClipboardMonitor.swift`: 클립보드 감시 + 알림 패널 추출
  - `ChannelUpdateService.swift`: 채널 업데이트 폴링 추출
- **Gemini API 백오프 통합**: `SummarizationService.summarizeVideo()` unified 메서드 추가 (yTeaser→Gemini 폴백 일원화)
  - `TaggingService.queryGemini`에 4회 재시도 + 선형 백오프 추가
  - HomeReducer, LibraryReducer 중복 폴백 로직 3곳 제거
- **자동 테스트 55개 추가**: ErrorMessageMapperTests(23), DownloadItemTests(17), ConstantsTests(15)

---

## v2.3.0 (2026-07-16) — SponsorBlock + 기능 다듬기

**macOS 26+ 전용** | Swift 6.3 | SPM 6.2

### New Features
- **SponsorBlock 지원**: 다운로드 시 스폰서/인트로/아웃트로 자동 제거 (시스템 탭 토글)
- **메타데이터/섬네일 임베딩**: 파일에 제목/채널/업로드 날짜/섬네일 자동 포함 (시스템 탭 토글)
- **다운로드 큐 개별 제어**: 각 항목 상태에 따라 일시정지/재개/재시도 버튼 제공
- **실패 시 에러 메시지 표시**: DownloadRow에 간략한 에러 이유 표시

### Improvements
- **에러 메시지 래핑** (`ErrorMessageMapper`): yt-dlp raw stderr → 한글 친화적 메시지 자동 변환
  - 403→"권한 필요", 404→"영상 없음", 410→"삭제됨", 연령 제한/비공개/멤버십 등 15개 패턴
  - `DownloadManager.swift`, `YouTubeDLService.swift` 양쪽 적용
- **라이브러리 벌크 액션**: 선택 모드에 "Finder에서 보기" + "열기" 버튼 + SF Symbol 아이콘 추가
  - GridView / ListView 양쪽 selectionBar 동시 적용
  - Cmd+Click 선택 수정 (`NSApp.currentEvent` → `NSEvent.modifierFlags`)
- **메뉴바 큐 요약**: 우클릭/클릭 메뉴에 다운로드 중/완료/대기 개수 + 속도 + ETA 표시
  - `RunLoop.common` 모드 타이머 + `menu.itemChanged()` 실시간 갱신
  - `startDownload`/`pauseDownload`/`resumeDownload` 시 statusBar 동기화
- **Home AI 요약 팝오버**: Discover/Library와 동일한 디자인으로 통일 (380×320, ScrollView, 복사 버튼)
- **채널 목록 우클릭 메뉴**: "Finder에서 채널 폴더 열기" 추가
- **순번 인덱스 개선**: 일반 URL 다운로드는 `fetchUploadIndex` 건너뜀 → `000 - ` prefix 저장
- **채널 새로고침 시 파일 rename**: `000 - ` prefix 파일을 올바른 순번으로 자동 변경
- **해상도 Picker 폭 증가**: 130pt → 200pt (긴 포맷 라벨 대응)
- **Discover 검색 아이콘 레이아웃 안정화**: ProgressView/Image 동일 frame 적용

### Infrastructure
- `Services/ErrorMessageMapper.swift` — 신규 파일 (yt-dlp 에러 매핑 유틸리티)
- `Settings.sponsorBlock`, `Settings.embedMetadata` — Bool 저장 필드 (기본값 true)
- `docs/TEST.md` — v2.3.0 테스트 명세서 및 결과

### Bug Fixes
- Cmd+Click으로 라이브러리 선택 안 되던 문제 수정
- 메뉴바 큐 요약이 다운로드 시작 직후 표시 안 되던 문제 수정
- 메뉴 열린 상태에서 큐 정보 실시간 갱신 안 되던 문제 수정
- Discover 검색 Enter 시 아이콘 레이아웃 깨짐 수정
- 영상 다운로더 해상도 Picker 라벨 잘림 수정
- **다운로드 성공해도 "실패"로 표시되는 문제 수정**: yt-dlp가 thumbnail/sponsorblock/post-processing 단계에서 non-zero exit code를 반환해도 실제 파일이 생성되었으면 성공으로 처리
  - `--print-to-file after_move:filepath`로 실제 출력 경로 추적
  - 종료 코드 + 파일 존재 여부 모두 확인하여 판단

## v2.2.0 (2026-07-16) — 설정 UI 전면 개편 (OpenCode Desktop 스타일)

**macOS 26+ 전용** | Swift 6.3 | SPM 6.2

### Breaking Changes
- **설정 창 UI 전면 개편**: 기존 접이식 VStack 패널 → YouTube/시스템 환경설정 스타일 4탭 레이아웃
  - 왼쪽: 탭 사이드바 (일반/저장/시스템/AI 요약)
  - 오른쪽: 선택된 탭의 설정 내용 (SettingsRow 리스트)
- **창 크기 변경**: 480×580 → 560×420 고정 (리사이즈 불가)
- **탭 이름 변경**: 다운로드→일반, 기타→시스템
- **SettingsView 구조 변경**: 기존 `settingRow`/`row`/`infoText` 3개 헬퍼 → 단일 `SettingsRow(title:description:control:)` 컴포넌트

### New Features
- **4탭 내비게이션** (`SettingsTab` enum): 일반/저장/시스템/AI 요약 — 왼쪽 탭 메뉴로 전환
  - 각 탭은 SF Symbol 아이콘 + 선택 하이라이트
- **OpenCode Desktop 스타일 SettingsRow**: Title + Description 수직 스택(좌) + Control(우)
  - Description은 Title 아래 오른쪽 정렬, 한 줄 고정
  - 항목 간 하단 border 구분
- **설명문 가시성 개선**: 모든 설정 설명 11pt, `.lineLimit(1)` + 우측 정렬
- **⌘, 단축키 글로벌 지원**: `NSEvent.addLocalMonitorForEvents`로 메인 창에서도 단축키 동작
- **해상도 Picker 순서 변경**: 상단=4K → 하단=144p (SettingsView, ChannelContentView, BatchDownloadView 3곳)
- **메인창 자동 표시 설정**: 시스템 탭에 토글 추가 (`Settings.showMainWindowOnLaunch`)
  - 끄면 앱 실행 시 메인 창을 열지 않음
  - `AppReducer.appDidFinishLaunching`에서 UserDefaults 로드 추가

### Removed
- **서비스 선택(SummaryServiceMode) 완전 제거**: AI 탭에서 "서비스" 드롭다운 제거, 항상 yTeaser 우선 → Gemini 자동 폴백
  - `Settings.swift` — `SummaryServiceMode` enum 제거
  - `Constants.swift` — `summaryServiceModeKey` 제거
  - `SettingsReducer.swift` — `summaryServiceMode` State/Action/init 제거
  - `LibraryReducer.swift`/`HomeReducer.swift` — UserDefaults 모드 읽기 제거, 429 시 Gemini 폴백으로 단순화
  - `SummarizationService.swift` — `SummaryError.quotaExceeded` 케이스 추가로 명확한 할당량 감지
- **항상 위에 고정 설정 제거**: 설정 창에서 항목 삭제, 각 창이 로컬 `@State`로 자체 관리
  - `AppReducer.alwaysOnTop` State/Action/handler 제거
  - `Settings.alwaysOnTop` 필드 제거
  - `VideoDownloadView` → `@State private var alwaysOnTop` 로컬 상태 전환

### UI Changes
- **섹션 헤더**: 9pt → 12pt semibold, 상하 여백 증가
- **설명문**: 8pt → 11pt (`.caption`), `lineLimit(1)` + `minimumScaleFactor(0.7)`로 잘림 방지
- **AI 요약 설명**: 서비스 전환 시 설명문 동적 변경, 하단 우선순위 안내 추가
- **API Key 입력**: 180pt → 200pt (파일명 템플릿과 동일), Billing 링크 폰트 증가
- **저장 폴더/파일명 템플릿**: 200pt 고정 폭 + 우측 정렬
- **설정 창 하단**: AI 요약 우선순위 안내 (yTeaser → Gemini fallback)

### Infrastructure
- `SettingsTab` enum: `Models/Settings.swift` 신규 (CaseIterable, icon 매핑)
- `SettingsRow<Control>`: 제네릭 뷰 컴포넌트 (`SettingsView.swift`)
- `Constants.showMainWindowOnLaunchKey` 저장 키 추가

## v2.1.0 (2026-07-16) — Google Gemini API 마이그레이션

**macOS 26+ 전용** | Swift 6.3 | SPM 6.2

### Breaking Changes
- **Ollama → Google Gemini API 전환**: SummarizationService 및 TaggingService가 Ollama 로컬 LLM 대신 Google Gemini API 사용
- **Ollama 의존성 제거**: 더 이상 Ollama 설치/실행 불필요

### New Features
- **Gemini API 키 설정**: 설정 창에 SecureField 추가 (UserDefaults 저장)
- **API 키 검증 알럿**: 키 없을 때 요약 버튼 클릭 시 알럿 → "설정 열기" / "키 발급 받기" 버튼
- 3개 요약 진입점(Home/Library/Discover) 모두 API 키 체크 추가

### Infrastructure
- `docs/SETUP_OLLAMA.md` → v2.1.0 마이그레이션 노트 추가
- `docs/SETUP_GEMINI.md` — Gemini 설정 문서 신규 작성

## v2.0.1 (2026-07-16) — AI 요약 팝업 UI 통일 + Discover UX 개선

**macOS 26+ 전용** | Swift 6.3 | SPM 6.2

### UI Improvements
- **사이드바 한글화**: Library→보관함, Discover→트랜드
- **트랜드 검색창**: 사이드바에 실시간 검색 필드 추가 (discoverSearchText → ytsearch)
- **카테고리 리스트 리디자인**: 드래그 핸들 + SF Symbol 아이콘 + 이름 + 드래그-드롭 순서변경 (카운트 제거)
  - `TrendingCategory.systemIcon` 프로퍼티 추가 (flame/music.note/desktopcomputer 등)
  - `FeaturedCategoryDropDelegate` 구현
  - 카테고리 순서 @AppStorage("categoryOrder") 영구 저장
- **DiscoverCard 레이아웃 안정화**: ZStack → `thumbnailView` + 3개 `.overlay()`로 변경
  - hover 버튼이 셀 레이아웃에 영향을 주지 않음 (제목/정보 밀림 현상 해결)
- **다운로드 완료 배지 가시성 개선**: 코너 체크마크 → 초록 배경 + 흰 아이콘 + 그림자, hover "다운로드 완료" → 초록 캡슐 배경
- **Discover popover 방향**: arrowEdge `.leading` → `.trailing` (버튼 오른쪽에 표시)

### AI 요약 UX 통일
- **Discover AI 요약**: 인라인 뷰 → `.popover(isPresented:arrowEdge:)` 네이티브 팝오버 (로딩/결과/에러 3상태)
  - `discoverSummaryVideoId`/`discoverSummaryText`/`discoverSummaryLoading` State
- **Library AI 요약**: 좌클릭 메뉴 → `.sheet` 모달로 변경
  - `librarySummaryVideoId`/`librarySummaryText`/`librarySummaryLoading` State
  - 기존 `showSummary`/`summaryResult`/`summaryFailed`/`dismissLibrarySummary` Action
  - 결과는 여전히 `LibraryItem.summary`에 영구 저장
- **HomeView(다운로더)**: AI 요약 버튼 + popover 추가
  - `HomeReducer.summaryText`/`summaryLoading`/`showSummaryPopover` State
  - `toggleSummaryPopover`/`summaryLoaded`/`summaryFailed`/`dismissSummary` Action
  - `SummarizationService` 재사용
- **Library 요약 sheet 내용**: `.frame(maxHeight: .infinity, alignment: .topLeading)` 상단 정렬

### Discover 다운로드 변경
- **다운로드 버튼**: 큐 직접 추가 → 다운로더 창 열고 URL 자동 조회 (`store.send(.home(.autoFetchInfo(...)))`)
- **다운로드 완료 감지**: `downloadedIds = Set(store.library.items.map(\.id))`로 Discover 카드에 표시
  - hover 메뉴: "재생"(로컬 파일 열기) / "다운로드 완료"(비활성화)로 변경
  - 썸네일 코너에 초록 체크마크 배지

### Bug Fixes
- **Local file 요약 실패**: `extractTranscriptFromLocalFile`에서 외부 자막 파일 없으면 `fetchTranscript(videoId:)`로 YouTube 자막 다운로드 fallback
- **LibraryItem 구버전 호환**: Custom `init(from:)`/`encode(to:)` — `tags`/`summary` `decodeIfPresent`로 구버전 JSON에서도 크래시 없이 로드
- **Library sheet 가려짐**: ZStack overlay → `.sheet`로 변경 (HoverPreviewPanel 등 별도 윈도우 위로 표시)

### Infrastructure
- `docs/SETUP_OLLAMA.md` — Ollama 설치/실행확인/문제해결 문서화

## v2.0.0 (2026-07-16) — Discover 탭 + AI 요약/자동 태깅

**macOS 26+ 전용** | Swift 6.3 | SPM 6.2

### New Features
- **Discover 탭**: 사이드바에 Library/Discover 네비게이션 추가, Discover 선택 시 카테고리별 YouTube 트렌딩/인기 영상 표시
  - 8개 카테고리: 전체, 음악, 기술, 게임, 뉴스, 스포츠, 엔터테인먼트, 교육
  - yt-dlp `ytsearch` 기반, 30분 TTL 캐싱 (중복 호출 방지)
  - 각 카드 호버 시 "다운로드" + "AI 요약" 버튼
  - 원클릭 다운로드 큐 추가
  - 오프라인 시 "인터넷 연결 필요" 안내 화면
- **AI 영상 요약** (Library 좌클릭 메뉴): 로컬 자막 → Ollama LLM 요약
  - 개요 + 핵심 포인트 생성, LibraryItem.summary에 저장/영구 보존
  - 오프라인에서도 기존 영상 요약 가능 (로컬 자막 파일 활용)
  - Ollama 필요 (`ollama pull llama3.2`)
- **AI 자동 태깅**: 다운로드 완료 시 title+channel 기반 자동 분류
  - Ollama 분류 (우선) + 키워드 기반 fallback
  - LibraryItem.tags에 저장, 추후 사이드바 필터로 활용
- **사이드바 네비게이션**: Library/Discover 전환 (SF Symbol + 텍스트)
  - Library 모드: 기존 검색/필터/채널 목록 유지
  - Discover 모드: 카테고리 리스트 표시

### Infrastructure
- **macOS 타겟 26+ 상향**: Package.swift `tools-version: 6.2`, `.macOS(.v26)`
- **Swift 6 동시성 에러 전면 수정**: 8개 파일 (ChannelModels, ChannelListView, BookmarkManager, DownloadManager, DebugLogManager, AppDelegate, LibraryGridView)
  - `nonisolated(unsafe)`, `@MainActor`, `@unchecked Sendable` 적용
- **LibraryCacheService.updateItem()** 추가: 개별 항목 tags/summary 업데이트 지원

### Services
- `TrendingService` (actor): yt-dlp 검색 + 30분 TTL 캐시
- `SummarizationService` (actor): 자막(VTT/SRT) 추출 → Ollama LLM 요약
- `TaggingService` (actor): Ollama 분류 + 키워드 기반 fallback

### New Files (6개)
- `Models/TrendingVideo.swift` — 트렌딩 영상 모델 + 카테고리 열거형
- `Features/Discover/DiscoverView.swift` — 카드 그리드 + 호버 메뉴
- `Services/TrendingService.swift` — yt-dlp 검색/캐싱
- `Services/SummarizationService.swift` — 자막→Ollama 요약 파이프라인
- `Services/TaggingService.swift` — Ollama+키워드 자동 분류

### Modified Files (12개)
- `Package.swift` → tools-version 6.2, macOS .v26
- `Info.plist` → v2.0.0, LSMinimumSystemVersion 26.0
- `Models/LibraryItem.swift` → tags, summary 프로퍼티
- `Features/Library/LibraryReducer.swift` → sidebarMode, discover/ summary/tagging actions
- `Features/Library/LibrarySidebarView.swift` → 상단 네비게이션 + Discover 카테고리
- `Features/Library/MainView.swift` → sidebarMode 콘텐츠 전환
- `Features/Library/LibraryGridView.swift` → "AI 요약" 메뉴, @MainActor 수정
- `Features/Library/LibraryListView.swift` → "AI 요약" 메뉴
- `App/AppReducer.swift` → discoverAddToQueue, 태깅 on download
- `Services/LibraryCacheService.swift` → updateItem() 메서드

### Requirements
- macOS 26+ (Apple Silicon)
- Ollama (`ollama pull llama3.2`) — AI 요약/태깅 선택 사항

## v1.2.0 (2026-07-16) — 채널 업데이트 알림 개선 + 디스크 사용량 표시

### New Features
- **채널 업데이트 알림 (T-114)**: 30분 타이머로 채널 최신 영상 감지, `channelsNewVideos`/`channelsSeenVideoIds` UserDefaults 키로 신규/확인 영상 추적
  - 뱃지 클릭 → 채널 다운로더 창 오픈 (첫 새 영상 채널 자동 선택)
  - `seenVideoIds` 도입: 사용자가 확인(채널 선택/새로고침)한 영상은 `seenIds`로 이동, 다운로드 안 해도 재감지 안 됨
  - 상태바 진행률: "업데이트 확인 중 (N/M)" 표시
  - DEBUG 로그: `channelLogManager` → `libraryLogManager`로 변경 (메인 창에 출력)
  - `ChannelRow`: 새 영상 채널에 빨간 ● 배지
  - `ChannelContentView.channelHeader`: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 배너
- **디스크 사용량**: LibrarySidebarView 하단에 `[폴더] Finder에서 보기  12.3 GB  ↻` 표시
  - `LibraryCacheService.calculateDiskUsage()` — `storageDirectory` + 캐시 디렉토리 합산
  - 앱 실행 시, 다운로드 완료 시, 항목 삭제 시, ↻ 버튼 클릭 시 재계산
- **저장 폴더 기본값 변경**: `~/Downloads` → `~/Documents/TubeKeep` (사용자 실수 삭제 방지)
- **변수명 리팩토링**: `outputDirectory` → `storageDirectory` (코드 전체 일괄 변경)
- **UI 텍스트 변경**: "출력 폴더" → "저장 폴더" (설정 창, 다운로드 큐)
- **JSON 키 호환성 유지**: `Settings.CodingKeys`로 `"outputDirectory"` 키 마이그레이션 없이 호환

### Bug Fixes
- **statusBar badge 자동 리셋 제거**: 뱃지가 10초 후 사라지지 않고 사용자 클릭 시까지 유지
- **openVideoDownloaderWindow**: `MainView` → `VideoDownloadView`로 수정 (잘못된 뷰 참조)
- **자막 배지 미표시**: 두 가지 원인 수정
  - Migration 코드가 자막 파일(`.vtt`/`.srt`)을 비디오로 잘못 인식해 `filePath`를 `.ko.vtt`로 저장하는 버그 — 확장자가 비디오인지 확인 후 강제 재설정
  - 비디오 파일(NFC)과 자막 파일(NFD) 간 Unicode 정규화 불일치로 `hasSubtitles()`가 자막 파일을 찾지 못하는 버그 — `contentsOfDirectory` + ASCII `hasSuffix` 매칭으로 NFC/NFD 차이에 영향받지 않음

### Migration
- **저장 폴더 변경 시 LibraryItem.filePath 자동 마이그레이션**: `LibraryCacheService.loadItems()`에서 `filePath`가 실제 파일이 존재하지 않으면 현재 `channelStorageDirectory`에서 video ID로 파일을 찾아 경로 자동 수정
  - 저장 폴더를 변경하고 기존 파일들을 직접 옮겨도 라이브러리 항목이 정상 동작 (삭제, Finder 열기 등)
  - `LibraryItem.filePath`를 `let` → `var`로 변경하여 런타임 수정 가능

### Housekeeping
- 모든 빌드 경고 해결 (Sendable captures, MainActor.run unused result, keypath inference)

## v1.1.0 (2026-07-16) — 설정 창 분리 + 뷰 이름 정리 + 이미지 캐싱 + 라이브러리 편의성

### Breaking Changes
- **앱 이름 변경**: `VideoDownloader` → **TubeKeep**
- **번들 ID**: `com.mdownload.videodownloader` → `com.tubekeep`
- **URL Scheme**: `mdownload://` → `tubekeep://`
- **설치 경로**: `~/Applications/VideoDownloader.app` → `~/Applications/TubeKeep.app`
- **UserDefaults Suite**: `com.mdownload.videodownloader.shared` → `com.tubekeep.shared`

### Image Caching
- **중앙 캐시 서비스 통일**: 모든 썸네일/아바타 로딩이 `LibraryCacheService`(NSCache + 디스크) 경유, 오프라인에서도 표시
- **캐시 디렉토리 수정**: `~/Library/Caches/com.mdownload.library/` → `com.tubekeep/` (리브랜딩 누락분) + 기존 캐시 자동 마이그레이션
- **AsyncImage 제거 (5개 뷰)**: 모든 `AsyncImage`를 `CachedThumbnailView`/`CachedAvatarView`로 교체
  - `HomeView`, `BatchDownloadView`, `DownloadQueueView`, `PlaylistSelectionView`, `ChannelContentView`
- **중복 뷰 제거**: `ChannelContentView` 내 private `CachedAvatarView`/`CachedThumbnailView` 삭제 → `Views/CachedImageViews.swift` 공유 뷰로 통일
- **LibrarySidebarView 아바타 버그 수정**: 비디오 `thumbnailURL`을 아바타로 잘못 사용하던 코드 제거, 캐시/플레이스홀더만 사용

### New Features
- **설정 창 분리 (⌘,)**: `AppDelegate.openSettingsWindow()`로 NSWindow 직접 관리, `TubeKeepApp`은 빈 Scene, 메뉴바 "설정..." + ⌘, 단축키 지원
- **뷰 이름 정리**: `MainView`(영상 다운로더) → `VideoDownloadView`, `LibraryView` → `MainView` (파일명/구조체명/참조 전체)
- **영상 다운로더에서 설정 영역 완전 제거**: `VideoDownloadView` 하단 `SettingsView` 삭제
- **UserDefaults 직접 읽기 → 공유 Store 참조**: `HomeReducer`, `DownloadQueueReducer`, `DownloadManager` 3곳
- **alwaysOnTop 비활성화**: 설정 창에서 회색 처리 + "영상 다운로더 창에서만 사용 가능" 안내
- **설정 창 크기 고정**: 가로 480px 고정, 세로 580px (contentMin/MaxSize)
- **NSUserNotification → UNUserNotificationCenter**: deprecated 해결, 앱 실행 시 권한 요청
- **라이브러리 앱 분리 → 단일 앱 복원**: 단일 바이너리 → `VideoDownloader.app` + `LibraryDownloader.app` → 단일 `TubeKeep.app`으로 통합
- **크로스 프로세스 통신 제거**: `DistributedNotificationCenter` + `NSRunningApplication.activate` 제거, `openMainWindow` 직접 호출
- **데이터 공유**: `UserDefaults(suiteName:)`으로 라이브러리 아이템 앱 간 동기화 + 기존 데이터 자동 마이그레이션
- **언어 지원**: `Constants.youtubeExtractorArgs` — 시스템 언어 기반 yt-dlp `--extractor-args youtube:lang=XX`
- **DEBUG Mock 테스트**: "상태바 테스트" + "채널 업데이트" 서브메뉴
- **채널 업데이트 알림 개선 (T-114)**:
  - 새 영상 ID를 `UserDefaults("channelsNewVideos")`에 채널별 저장 → 상태바 뱃지 자동 리셋 제거 (클릭 시까지 유지)
  - 뱃지 클릭 → 채널 다운로더 창 (첫 새 영상 채널 자동 선택)
  - `ChannelRow`: 새 영상 채널 빨간 ● 배지 (아바타 우상단)
  - `ChannelContentView.channelHeader`: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 오렌지 배너
  - 채널 선택 시 `ChannelDownloadCache.saveSeenVideoIds`로 newIds를 seenIds로 이동 → 다운로드 안 해도 재감지 안 됨
  - `channelsSeenVideoIds` 도입 (UserDefaults): 확인한 영상은 다음 체크에서 제외
  - 다운로드 완료 시 `removeSeenVideoIds` 호출 (seenIds 정리)
  - 체크 진행률: 상태바 `"업데이트 확인 중 (N/M)"` 표시
  - 체크 DEBUG 로그: 채널 다운로더 창 `channelLogManager`에 출력
  - DEBUG "채널 업데이트" → 실제 `checkChannelUpdates` 실행으로 변경
- **라이브러리 재생시간 표시**: `LibraryItem.duration: Int?` + `formatDuration()`; 그리드/목록 뷰에 duration 오버레이
- **라이브러리 채널 영상 인덱스**: `LibraryItem.channelUploadIndex: Int?` — 채널 내 업로드 순서 추적 (001=최신); `LibraryCacheService.updateChannelUploadIndices()`로 자동 업데이트
- **정렬 옵션 확장**: `LibrarySortOrder`에 `indexAsc`/"인덱스순", `indexDesc`/"인덱스 역순" 추가; 채널 선택 시 기본 정렬 = 인덱스 역순
- **UI 인덱스 표시**: 그리드 썸네일 좌하단 `#003` 배지 + 목록 뷰 정보 열에 인덱스 표시

### Bug Fixes
- **채널 @handle 누락**: `fetchAllVideos`에서 handle에 `@` 자동 추가 (저장된 handle 포맷 차이 대응)
- **회원 전용 영상 차단**: `--playlist-items 0` → `--flat-playlist --playlist-end 1` (channel metadata fetch)
- **Short 필터링**: `fetchAllVideos`에서 `webpage_url.contains("/shorts/")` 체크
- **채널 목록 정렬**: 신규 채널이 항상 맨 위에 추가되도록 `insert(at: 0)` (3개 위치 + LibraryReducer)
- **창 전환 지연**: `NSWorkspace.shared.openApplication` → `NSRunningApplication.activate` (실행 중인 앱 직접 활성화)
- **사이드바 채널 아바타 미표시** (v1.0.0): 캐시 미스 시 다운로드 로직 추가
- **필터 전환 시 썸네일 깨짐** (v1.0.0): 불필요한 removeAll 제거
- **채널 새로고침 시 다운로드 체크 누락**: `syncDownloadedIDsFromDisk()`가 호출되지 않아 디스크 파일과 UserDefaults 캐시 불일치; refresh 후 호출 추가
- **macOS 권한 팝업 반복**: `BookmarkManager`(security-scoped bookmark) 도입으로 출력 폴더 접근 권한 1회 획득 후 유지
- **CachedImageViews actor isolation 경고**: `await` 추가로 Swift 6 준수
- **AppDelegate Sendable closure capture 경고**: 로컬 상수 캡처로 수정

### UI Improvements
- **채널 카운트**: `ChannelListView` 하단 `등록된 채널 N개` (아이콘 + 배경)
- **채널 추가 버튼**: `ChannelContentView` empty state에 "채널 추가" 버튼 (`onAddChannel`)
- **자막 다운로드 뱃지**: 썸네일 우측 상단 고정
- **호버 미리보기 위치**: 셀 중앙 기준 왼쪽으로 확장 (`cell.midX - 360`), 하단 기준=셀 상단 → 중앙 (`maxY+5` → `midY`) — 썸네일 우상단 1/4 가림
- **메뉴바 메뉴**: 모든 항목 `target: self` 명시 (Selector 불일치 방지)
- **정보 창**: 새로운 "정보" 메뉴 항목 + AboutView
- **채널 아바타 동그랗게**: `CachedAvatarView`에 `.clipShape(Circle())` 적용; `ChannelListView` 왼쪽 패딩 12px
- **메뉴바 "설정..." 추가**: ⌘, 단축키, AppDelegate 메뉴 재구성

### Housekeeping
- `Sources/MDownload/` → `Sources/TubeKeep/` 디렉토리 리네임
- `Sources/MDownloadCore/` → `Sources/MDownload/` 통합 (단일 모듈)
- `FixedWidthWindowController` 별도 파일로 분리
- **단일 `.app` 복원**: `LibraryDownloader.app` 제거, 단일 `TubeKeep.app`으로 통합
- `DebugLogView`: 각 window에 DEBUG 전용 동작 로그 패널 추가 (자동 스크롤 + 복사 가능)
- `LibraryInfo.plist` 삭제
- `build_and_run.sh`: 앱 이름 `VideoDownloader` → `TubeKeep`, `--clean` 옵션 추가 (기본 增量 빌드)
- `docs/IMAGE_CACHING.md` — 이미지 캐싱 아키텍처 문서 추가
- `CachedImageViews.swift` — 공유 `CachedThumbnailView`/`CachedAvatarView` 뷰 파일 생성
- `BookmarkManager.swift` — security-scoped bookmark 관리 유틸리티 (접근 권한 1회 획득 후 재시작 시 자동 복원)
- 모든 Swift 6 Sendable 경고 수정 (0 warnings)

---

## v1.0.0 (2026-07-14) — Initial Release

### Milestone: 라이브러리 대시보드 (M5) 완료
- LibraryItem 모델 + LibraryReducer (sort/filter/search + viewMode)
- LibraryCacheService (메모리+디스크 썸네일/아바타 캐시)
- LibraryView (HStack: sidebar 200px + content, toolbar)
- LibrarySidebarView (검색, 전체/최근, 채널 목록 + 우클릭)
- LibraryGridView (LazyVGrid, 인피니트스크롤, 좌클릭 NSMenu)
- LibraryListView (LazyVStack, 동일 메뉴)
- EmptyLibraryCell (full-width 안내 + 3개 다운로더 버튼)
- AppDelegate 메뉴/창 분리 (라이브러리=main 자동실행, 다운로더=별도)
- downloadCompleted → library 저장 + race condition 수정

### Bug Fixes
- `-[NSIndirectTaggedPointerString count]` crash → `OSAllocatedUnfairLock`
- 다운로드 개수 불일치 → sequential save+load
- "다운로드" 버튼 잘못된 창 → `openDownloaderWindowNotification`
- 모든 Swift 6 Sendable 경고 수정 (0 warnings)
- 그리드 레이아웃 리사이즈 깨짐 → EmptyLibraryCell 분리
- FixedWidthWindowController dealloc → AppDelegate 프로퍼티 저장
- 사이드바 채널 아바타 미표시 → 캐시 미스 시 다운로드 로직 추가

### UX Improvements
- 메뉴바 "라이브러리" 아래 구분선 추가
- 그리드/목록 뷰모드 전환 (sortBar 우측 토글, UserDefaults 저장)
- 좌클릭 NSMenu (LeftClickMenu, NSViewRepresentable)
- 클립보드 감지 — 라이브러리 창 열려 있어도 다운로더 창 오픈
- 자동 실행 (build_and_run.sh open 추가)
- build/ 디렉토리 gitignore 추가

### Housekeeping
- 사용하지 않는 `queueSaveKey` 상수 제거
- 문서 전용 폴더 `docs/` 생성 및 이동 (AGENTS/PRD/DESIGN/PLAN/TODO)
- Git init + tag v1.0.0
- Release 아카이브: `Releases/v1.0.0/` (VideoDownloader.app + source.zip)
