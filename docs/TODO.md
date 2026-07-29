# TODO — 작업 추적 목록

## v1.1.0 — 라이브러리 편의성 + 핵심 기능 확장

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-110 | **다운로드 폴더 열기 버튼** — sidebar 하단에 출력폴더 바로가기 | high | completed | ✅ |
| T-111 | **그리드 셀 hover 썸네일 확대 툴팁** — 셀 위에 마우스 올리면 큰 썸네일 미리보기 | medium | completed | ✅ |
| T-112 | **여러 항목 선택 → 일괄 삭제** — Cmd+클릭 다중 선택 + selection bar 일괄 삭제 | medium | completed | ✅ |
| T-113 | **브라우저 URL Scheme** — `tubekeep://` 커스텀 scheme 등록, 브라우저에서 원클릭 전송 | high | completed | ✅ |
| T-114 | **채널 구독 업데이트 알림** — seenVideoIds 도입, 진행률 표시, DEBUG 로그 | high | completed | DEBUG>채널 업데이트 (DEBUG) + 채널다운로더 로그 |
| T-115 | **다운로드 큐 영속성** — 앱 재시작해도 진행/대기 중인 다운로드 유지 (상태 정기 저장) | high | completed | ✅ |
| T-116 | **자막 별도 다운로드** — 라이브러리 우클릭 → "자막 다운로드" (yt-dlp --write-subs) | medium | completed | ✅ |
| T-117 | **사이드바 채널 drag-to-reorder** — 채널 목록 드래그로 순서 변경, UserDefaults에 순서 저장, 가나다순 대체 | medium | completed | ✅ |
| T-118 | **사이드바 "채널 추가" 버튼** — 채널 목록 하단에 `+` 버튼 → 채널 다운로더 창 열기 | medium | completed | ✅ |
| T-119 | **업로드 날짜 필드 추가 + 정렬 확장** — `LibraryItem.uploadDate` 추가, 정렬 옵션에 업로드 최신순/오래된순 추가, 채널 선택 시 기본 정렬 업로드순 | high | completed | ✅ |
| T-120 | **이미지 캐싱 전면 개선** — 모든 AsyncImage 제거, CachedThumbnailView/CachedAvatarView 통일, 캐시 디렉토리 경로 수정 + 마이그레이션 | high | completed | ✅ |
| T-121 | **라이브러리 재생시간 표시** — `LibraryItem.duration` + `formatDuration()`, 그리드/목록 UI 오버레이 | medium | completed | ✅ |
| T-122 | **채널 아바타 동그랗게** — CachedAvatarView clipShape(Circle), ChannelListView padding | low | completed | ✅ |
| T-123 | **채널 영상 인덱스 기능** — `LibraryItem.channelUploadIndex`, `LibraryCacheService.updateChannelUploadIndices`, `AppReducer` 전달, `LibrarySortOrder` indexAsc/indexDesc, 그리드/목록 UI 표시 | high | completed | ✅ |
| T-124 | **새로고침 시 디스크 동기화** — `ChannelDownloadCache.syncDownloadedIDsFromDisk()` 호출 누락 수정 | high | completed | ✅ |
| T-125 | **build_and_run.sh --clean 옵션** — clean 빌드와 增量 빌드 분리 | low | completed | ✅ |

## v1.2.0 — 채널 업데이트 알림 개선 + 디스크 사용량 표시

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-126 | **디스크 사용량 계산** — `LibraryCacheService.calculateDiskUsage()`, `LibraryReducer` diskUsageBytes State/액션 | medium | completed | ✅ |
| T-127 | **디스크 사용량 UI** — LibrarySidebarView 하단 `Finder에서 보기  12.3 GB  ↻` | medium | completed | ✅ |
| T-128 | **채널 업데이트 알림 개선** — seenVideoIds, 진행률 상태바, DEBUG 로그 출력 위치 변경 | high | completed | ✅ |

## v2.0.1 — AI 요약 팝업 UI 통일 + Discover UX 개선

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-200 | **사이드바 한글화** — Library→보관함, Discover→트랜드 | low | completed | |
| T-201 | **트랜드 검색창** — 사이드바 검색 필드 | medium | completed | |
| T-202 | **카테고리 리스트 리디자인** — 드래그 핸들 + SF Symbol + 순서변경 (카운트 제거) | medium | completed | |
| T-203 | **DiscoverCard overlay 안정화** — ZStack → `.overlay()`로 변경 | high | completed | hover 버튼 레이아웃 영향 제거 |
| T-204 | **AI 요약 UX 통일** — Discover/Library/Home 모두 popover/sheet로 통일 | high | completed | |
| T-205 | **Local file 요약 fallback** — 외부 자막 없으면 YouTube 자막 fetch | high | completed | |
| T-206 | **다운로드 완료 배지 가시성** — Discover 카드 초록 배경 + 캡슐 | low | completed | |
| T-207 | **LibraryItem 구버전 호환** — tags/summary decodeIfPresent | high | completed | |

## v2.1.0 — Google Gemini API 마이그레이션

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-300 | **Gemini API 키 설정 UI** — SecureField + 발급 링크 (SettingsView) | high | completed | |
| T-301 | **SettingsReducer + Settings 모델** — geminiAPIKey State/Action | high | completed | |
| T-302 | **SummarizationService Gemini 마이그레이션** — queryOllama → queryGemini | high | completed | |
| T-303 | **TaggingService Gemini 마이그레이션** — queryOllama → queryGemini | high | completed | |
| T-304 | **API 키 체크 알럿** — Library/Discover/Home 3곳 showGeminiKeyAlert + openSettingsForGeminiKey | high | completed | |
| T-305 | **Constants + AppDelegate** — openSettingsWindowNotification | high | completed | |
| T-306 | **문서 업데이트** — SETUP_GEMINI.md 신규, SETUP_OLLAMA.md 레거시 표시 | medium | completed | |

## v2.2.0 — 설정 UI 전면 개편 + SummaryServiceMode 제거

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-400 | **4탭 설정 레이아웃** — SettingsTab enum (일반/저장/시스템/AI 요약), 좌 140pt 사이드바 + 우 ScrollView | high | completed | |
| T-401 | **SettingsRow 컴포넌트** — 제네릭 `VStack { HStack(title, control) + Text(desc, .trailing) }` | high | completed | 기존 3개 헬퍼 통합 |
| T-402 | **창 크기 560×420 고정** — NSWindow contentMinSize/MaxSize + 리사이즈 불가 | high | completed | |
| T-403 | **⌘, 단축키 글로벌 모니터** — NSEvent.addLocalMonitorForEvents | high | completed | 메인 창에서도 동작 |
| T-404 | **summaryServiceMode stored property** — computed→stored 전환, UserDefaults init, 직접 저장 | high | completed | @ObservableState 바인딩 |
| T-405 | **alwaysOnTop 설정 제거** — AppReducer/Settings 필드 삭제, 3개 창 로컬 `@State` | high | completed | |
| T-406 | **해상도 Picker 순서 통일** — SettingsView/ChannelContentView/BatchDownloadView 4K→144p | medium | completed | |
| T-407 | **showMainWindowOnLaunch** — Settings 토글 + AppReducer.appDidFinishLaunching 로드 | medium | completed | |
| T-408 | **AI 요약 탭 — SummaryServiceMode 제거** — 서비스 드롭다운 삭제, yTeaser/Gemini 고정 배치, 429 시 자동 폴백 | high | completed | `SummaryError.quotaExceeded` 추가 |
| T-409 | **AI 탭 UI 재구성** — yTeaser(설명+항상사용) / Gemini(API Key 입력+Billing링크) 고정 영역 | high | completed | |
| T-410 | **설명문 UI 개선** — 8pt→11pt, .trailing 정렬, lineLimit(1), minimumScaleFactor | low | completed | |

## v2.3.0 — SponsorBlock + 기능 다듬기

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-500 | **SponsorBlock** — `--sponsorblock-remove all` 플래그 + 시스템 탭 토글 | high | completed | yt-dlp 내장 |
| T-501 | **메타데이터/섬네일 임베딩** — `--embed-metadata --embed-thumbnail` + 시스템 탭 토글 | high | completed | |
| T-502 | **다운로드 큐 개별 제어** — DownloadRow 상태별 pause/resume/retry 버튼 | high | completed | |
| T-503 | **에러 메시지 래핑** — ErrorMessageMapper + DownloadManager/YouTubeDLService 적용 | medium | completed | 15개 패턴 매핑 |
| T-504 | **라이브러리 벌크 액션** — revealSelectedInFinder + openSelected + selectionBar 버튼 | high | completed | Grid/List 양쪽 |
| T-505 | **메뉴바 큐 요약** — 드롭다운에 다운로드 중/완료/대기 개수 + 속도 + ETA | medium | completed | |

## 제외 (v1.1.0 범위 외)

| 작업 | 사유 |
|------|------|
| 파일 포맷별 필터 | 불필요 |
| 알림음 커스터마이징 | 불필요 |
| 라이브러리 CSV/JSON export | 불필요 |
| 재생목록 파일 생성 | 불필요 |
| 시작 프로그램 지연 실행 | 보류 |
| 검색 개선 | 현재 수준으로 충분 |

---

## 완료된 작업 (v1.0.0)

| ID | 작업 | 상태 | 비고 |
|----|------|------|------|
| T-90 | **LibraryItem 모델** — LibraryItem, LibrarySortOrder, LibraryFilterMode, LibraryViewMode | ✅ completed | |
| T-91 | **LibraryReducer** — State/Action/Reducer + UserDefaults 저장/로드 + viewMode | ✅ completed | |
| T-92 | **LibraryCacheService** — 썸네일/아바타 디스크+메모리 캐시 | ✅ completed | |
| T-93 | **LibraryView** — HStack (sidebar 200px + content) + toolbar | ✅ completed | |
| T-94 | **LibrarySidebarView** — 검색창 + 전체/최근 + 채널 목록 + 우클릭 메뉴 | ✅ completed | |
| T-95 | **LibraryGridView** — LazyVGrid, 인피니트스크롤, EmptyLibraryCell, LeftClickMenu | ✅ completed | |
| T-96 | **LibraryGridCell** — 16:9 썸네일 + 제목 + 채널명 + 날짜, 좌클릭 NSMenu | ✅ completed | |
| T-97 | **EmptyLibraryCell** — 빈 상태 + [영상다운][일괄다운][채널다운] 버튼 | ✅ completed | |
| T-98 | **AppDelegate 메뉴/창 분리** — 라이브러리=main 자동실행, 하단 구분선 | ✅ completed | |
| T-99 | **DownloadQueue → Library 저장** — downloadCompleted → addItem + loadFromDisk | ✅ completed | |
| T-100 | **LibraryListView** — LazyVStack 목록 모드 | ✅ completed | |
| T-101 | **FixedWidthWindowController** — 가로폭 840 고정 | ✅ completed | |
| T-102 | **좌클릭 NSMenu** — NSViewRepresentable LeftClickMenu | ✅ completed | |
| T-103 | **그리드/목록 뷰모드 전환** — sortBar 우측 토글 | ✅ completed | |
| T-104 | **클립보드 감시 개선** — 라이브러리 창 열려 있어도 다운로더 창 열고 autoFetch | ✅ completed | |

### M1~M4 완료 목록
| ID | 작업 | 상태 |
|----|------|------|
| T-01~T-59 | M1~M3 기본 기능 (메뉴바, URL 입력, 다운로드, 설정) | ✅ completed |
| T-60~T-87 | M4 채널 다운로더 | ✅ completed |

---

## 테스트 참고

### v1.1.0 테스트용 URL

| 용도 | URL |
|------|-----|
| 기본 영상 (1MB 이하) | `https://youtu.be/IL8auam0Ujg` |
| 채널 다운로더 | `https://www.youtube.com/@ManCarryingThing` |
| URL Scheme | `tubekeep://https://youtu.be/IL8auam0Ujg` |

### 추가 테스트 필요 항목

| 기능 | 필요한 조건 |
|------|-----------|
| T-116 자막 다운로드 | 자막(ko/en)이 포함된 영상 |
| T-113 URL Scheme | `tubekeep://` scheme 처리 |
| T-114 채널 업데이트 | 채널 구독 → DEBUG "채널 업데이트 (DEBUG)" 메뉴 or 30분 대기 |
| T-115 큐 영속성 | 다운 중 앱 종료 → 재시작 |
| T-111 hover 툴팁 | 라이브러리 그리드 hover |
| T-112 다중 선택 삭제 | Cmd+클릭 여러개 선택 → 삭제 |
| 파일명 {id} 강제 | 템플릿에 {id} 없어도 파일명에 ID 포함 확인 |

---

## v1.2.0 — 설정 창 분리 + 뷰 이름 정리

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-126 | **뷰 이름 변경** — MainView→VideoDownloadView, LibraryView→MainView (파일명/구조체명/참조 전체) | high | completed | 빌드 성공 |
| T-127 | **네이티브 설정 창 (⌘,)** — Settings 씬에 SettingsView 연결, 공유 Store 주입 | high | completed | ⌘,로 열림 |
| T-128 | **영상 다운로더에서 설정 영역 완전 제거** — VideoDownloadView 하단 SettingsView 삭제 | high | completed | 설정 영역 없음 |
| T-129 | **메뉴바 "설정..." 추가 (⌘, 단축키)** — AppDelegate 메뉴 재구성 | medium | completed | 메뉴바에서 열림 |
| T-130 | **UserDefaults 직접 읽기 → 공유 Store 참조로 변경** — HomeReducer, DownloadQueueReducer, DownloadManager 3곳 | high | completed | 설정 변경 즉시 반영 |
| T-131 | **alwaysOnTop 설정 비활성화** — 설정 창에서 비활성/안내 표시 (메인 윈도우 전용 속성) | medium | completed | 회색 처리됨 |

## 취소됨

| ID | 작업 | 사유 |
|----|------|------|
| T-16 | 큐 검색/정렬 | 불필요 |
| T-17 | 속도 측정 URL 안정화 | 기존 fallback 유지 |
| T-18 | iCloud 히스토리 동기화 | 복잡도 대비 효용 낮음 |
| T-19 | 자동 업데이트 (Sparkle) | 범위 외 |
| T-20 | macOS Notification Center 배너 | 메뉴바 badge로 충분 |
| T-21 | 브라우저 확장 | 클립보드 감시로 대체 |

## v2.3.0 — SponsorBlock + 기능 다듬기 (2026-07-16) 🏁

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-200 | SponsorBlock 지원 (시스템 탭 토글) | high | completed | TC-01 ⬜ |
| T-201 | 메타데이터/섬네일 임베딩 | high | completed | TC-02 ✅ |
| T-202 | 다운로드 큐 개별 제어 | high | completed | TC-03 ✅ |
| T-203 | ErrorMessageMapper 한글화 (15패턴) | medium | completed | TC-04 ✅ |
| T-204 | 라이브러리 벌크 액션 (Finder/열기/선택) | medium | completed | TC-05 ✅ |
| T-205 | 메뉴바 큐 요약 (실시간 갱신) | medium | completed | TC-06 ✅ |
| T-206 | 설정 지속성 | medium | completed | TC-07 ✅ |
| T-207 | 회귀 테스트 (11/11) | high | completed | TC-08 ✅ |
| T-208 | Discover 검색 아이콘 레이아웃 안정화 | low | completed | ✅ |
| T-209 | 해상도 Picker 130pt→200pt | low | completed | ✅ |
| T-210 | 순번 인덱스 개선 (000 prefix, 채널 rename) | medium | completed | ✅ |
| T-211 | Home AI 요약 팝오버 디자인 통일 | low | completed | ✅ |
| T-212 | Cmd+Click 선택 수정 (NSEvent.modifierFlags) | medium | completed | ✅ |
| T-213 | StatusBar 다운로드 동기화 (start/pause/resume) | medium | completed | ✅ |
| T-214 | 메뉴바 Timer RunLoop.common 등록 + itemChanged | medium | completed | ✅ |

## v2.4.0 — 기술부채 해소 + SwiftData 전환 + A.X 4.0 통합 (2026-07-16) 🏁

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-300 | SwiftData 마이그레이션 (LibraryItem, SubscribedChannel → @Model) | high | completed | 빌드+55테스트 ✅ |
| T-301 | AppDelegate 분리 (StatusBarManager, ClipboardMonitor, ChannelUpdateService) | high | completed | 빌드 ✅ |
| T-302 | Gemini API 백오프 통합 (summarizeVideo unified, 4회 재시도) | high | completed | 빌드 ✅ |
| T-303 | 자동 테스트 (ErrorMessageMapper 23 + DownloadItem 17 + Constants 15) | medium | completed | 55개 ✅ |
| T-304 | macOS 14+ 플랫폼 타겟 상향 (SwiftData 필요) | high | completed | ✅ |
| T-306 | SKT A.X 4.0 API 클라이언트 추가 (OpenAI 호환) | high | completed | 빌드+55테스트 ✅ |
| T-307 | 설정 UI - A.X 4.0 API 키 관리 (공개 키 기본값) | high | completed | 빌드 ✅ |
| T-308 | 요약 폴백 체인 변경: A.X 4.0 → yTeaser → Gemini | high | completed | 빌드+55테스트 ✅ |
| T-309 | 태깅 폴백 체인 변경: A.X 4.0 → Gemini → autoClassify | high | completed | 빌드+55테스트 ✅ |
| T-310 | 한글 맞춤법 수정 (소스+문서) | medium | completed | 55개 ✅ |
| T-311 | OpenRouter Free Tier 서비스 추가 (OpenAI 호환) | high | completed | 빌드+55테스트 ✅ |
| T-312 | 요약 폴백 체인 변경: OpenRouter → yTeaser → A.X 4.0 → Gemini | high | completed | 빌드+55테스트 ✅ |
| T-313 | 태깅 폴백 체인 변경: OpenRouter → A.X 4.0 → Gemini → autoClassify | high | completed | 빌드+55테스트 ✅ |
| T-314 | 설정 UI — OpenRouter API 키 입력 + "무료 가입" 링크 | high | completed | 빌드+55테스트 ✅ |
| T-305 | 모듈 분리 (TubeKeepCore + TubeKeep) | medium | cancelled | 단일 모듈로 충분, 분리할 실질적 이점 없음 |

## v2.5.0—v2.5.6 — AI 콘텐츠 캐싱 + 챕터/팟캐스트/Q&A/마인드맵 + UI 통합 + 최종 테스트 (2026-07-17~19) 🏁

**버전 체계**: v2.5.0 → v2.5.1 → ... → v2.5.6 (+0.0.1씩 증가)

### 챕터 1: SQLite DB 구축 + 자막 캐싱 (v2.5.0)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-500 | **DatabaseManager.swift 생성** — SQLite3 오픈/생성, 테이블 생성 | high | completed | ✅ |
| T-501 | **video_ai_data 테이블 생성** — CREATE TABLE IF NOT EXISTS | high | completed | ✅ |
| T-502 | **CRUD 메서드 구현** — save/load/update/delete | high | completed | ✅ |
| T-503 | **SummarizationService 자막 DB 저장** — fetch 후 DB 저장 | high | completed | ✅ |
| T-504 | **SummarizationService 자막 DB 로드** — DB에서 로드 (재사용) | high | completed | ✅ |
| T-505 | **LibraryCacheService DB 동기화** — 요약 저장 시 DB도 저장 | high | completed | ✅ |
| T-506 | **LibraryItem 새 속성 추가** — transcript, chapters | high | completed | ✅ |
| T-507 | **Info.plist 버전 2.5.0 + Bundle ID 수정** | medium | completed | ✅ |
| T-508 | **자막 파일 → DB 저장 전환** — 다운로드 시 임시 저장 후 DB 저장 + 파일 삭제 | high | completed | ✅ |
| T-509 | **DownloadManager 자막 DB 저장** — 비디오 다운로드 시 자막도 DB 저장 | high | completed | ✅ |
| T-510 | **기존 자막 파일 마이그레이션** — 17개 .vtt 파일 DB 저장 후 디스크 삭제 | high | completed | ✅ |
| T-511 | **키보드 단축키 keyCode 수정** — 한글 레이아웃 호환 (event.keyCode 사용) | high | completed | ✅ |
| T-512 | **DebugLogManager 초기화 시점 수정** — applicationDidFinishLaunching 즉시 초기화 | medium | completed | ✅ |
| T-513 | **AI 요약 DB 캐싱 — 확인** — summarizeVideo() API 호출 전 DB에서 기존 요약 확인 | high | completed | ✅ |
| T-514 | **AI 요약 DB 캐싱 — 저장** — summaryResult 시 DatabaseManager.updateSummary() 호출 | high | completed | ✅ |
| T-515 | **AI 요약 DB 캐싱 — 표시** — showSummary 시 item.summary 먼저 확인 | high | completed | ✅ |
| T-516 | **자막 가용성 DB 체크** — hasSubtitles()를 파일시스템 → DB 체크로 변경 | high | completed | ✅ |

### 챕터 2: AI 요약 + 챕터 생성 (v2.5.1)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-510 | **ChapterInfo 모델 생성** — Codable, Identifiable | high | completed | ✅ |
| T-511 | **SummaryResult에 chapters 필드 추가** | high | completed | ✅ |
| T-512 | **SummarizationService 프롬프트 변경** — 챕터 형식 추가 | high | completed | ✅ |
| T-513 | **OpenRouterService 프롬프트 변경** | high | completed | ✅ |
| T-514 | **AX4Service 프롬프트 변경** | high | completed | ✅ |
| T-515 | **챕터 응답 파싱 로직** | high | completed | ✅ |
| T-516 | **DB에 챕터 저장** | high | completed | ✅ |
| T-517 | **LibraryGridView 챕터 표시 UI** | medium | completed | ✅ |
| T-518 | **LibraryListView 챕터 표시 UI** | medium | completed | ✅ |
| T-519 | **Info.plist 버전 2.5.1** | medium | completed | ✅ |

### 챕터 3: AI 팟캐스트 생성 (v2.5.2) — macOS 내장 TTS (무료)

**TTS 엔진**: AVSpeechSynthesizer (macOS 내장, 완전 무료, 오프라인)
**대화 스크립트**: 기존 LLM 폴백 체인 활용 (OpenRouter → yTeaser → A.X 4.0 → Gemini)

#### 3-1. 데이터 모델 + 서비스

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-520 | **PodcastService.swift 생성** — 팟캐스트 생성 서비스 (actor) | high | completed | ✅ |
| T-520a | **PodcastScript 모델** — PodcastSegment, PodcastResult 모델 정의 | high | completed | ✅ |
| T-521 | **AI 대화 스크립트 생성 프롬프트** — 2인 대화 (진행자A/B), 15~25 세그먼트 | high | completed | ✅ |
| T-522 | **TTSService 생성** — AVSpeechSynthesizer 래퍼, 한국어 음성 선택 | high | completed | ✅ |

#### 3-2. 오디오 생성 + 저장

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-523 | **오디오 파일 저장 로직** — `~/Documents/TubeKeep/Podcasts/{videoId}/` | high | completed | ✅ |
| T-524 | **DB에 podcast_path 저장** — DatabaseManager.updatePodcastPath() | high | completed | ✅ |

#### 3-3. UI 통합

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-525 | **요약 팝업에 팟캐스트 컨트롤 추가** — 재생/일시정지/정지 버튼 + 진행 바 | medium | completed | ✅ |
| T-526 | **컨텍스트 메뉴 팟캐스트 항목** — 팟캐스트 만들기/듣기/삭제 | medium | completed | ✅ |
| T-527 | **LibraryReducer 팟캐스트 액션** — generatePodcast/playPodcast/deletePodcast | high | completed | ✅ |

#### 3-4. 마무리

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-528 | **팟캐스트 파일 정리** — 삭제 시 DB + 디렉토리 삭제 | medium | completed | ✅ |
| T-529 | **Info.plist 버전 2.5.2** | medium | completed | ✅ |

### 챕터 4: 트랜스크립트 Q&A (v2.5.3)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-530 | **QAService.swift 생성** — Q&A 서비스 | high | completed | ✅ |
| T-531 | **qna_history 테이블 생성** | high | completed | ✅ |
| T-532 | **Q&A 프롬프트 설계** | high | completed | ✅ |
| T-533 | **QAView UI** | high | completed | ✅ |
| T-534 | **LibraryReducer Q&A 액션** | medium | completed | ✅ |
| T-535 | **Q&A 히스토리 저장/로드** | medium | completed | ✅ |
| T-536 | **타임스탬프 클릭 → 재생 위치 이동** | medium | completed | ✅ |
| T-537 | **Info.plist 버전 2.5.3** | medium | completed | ✅ |

### 챕터 5: 마인드맵 생성 (v2.5.4)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-540 | **MindmapNode 모델 생성** | high | completed | ✅ |
| T-541 | **MindmapService.swift 생성** | high | completed | ✅ |
| T-542 | **마인드맵 생성 프롬프트** | high | completed | ✅ |
| T-543 | **DB에 마인드맵 저장** | high | completed | ✅ |
| T-544 | **MindmapView UI** | medium | completed | ✅ |
| T-545 | **마인드맵 노드 확장/축소** | low | completed | ✅ |
| T-546 | **마인드맵 이미지 내보내기** | low | cancelled | 패스 |
| T-547 | **Info.plist 버전 2.5.4** | medium | completed | ✅ |

### 챕터 6: UI 통합 + 챕터 표시 (v2.5.5)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-550 | **LibraryGridView 챕터 표시** | high | completed | ✅ (v2.5.1에서 완료) |
| T-551 | **LibraryListView 챕터 표시** | high | completed | ✅ (v2.5.1에서 완료) |
| T-552 | **액션 메뉴 통합 (3→1 "AI 기능")** | high | completed | ✅ |
| T-553 | **AIWindowView 좌우 split 레이아웃** | medium | completed | ✅ |
| T-554 | **팟캐스트 시간 왼쪽 표시** | medium | completed | ✅ |
| T-555 | **다크모드 오버레이 + 자동 포커스 방지** | medium | completed | ✅ |
| T-556 | **Info.plist 버전 2.5.5** | medium | completed | ✅ |

### 챕터 7: 마이그레이션 + 테스트 (v2.5.6)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-560 | **DatabaseManager 마이그레이션 로직** | high | completed | 배포 전 검증 |
| T-561 | **기존 데이터 동기화 (summary→DB)** | high | completed | 배포 전 검증 |
| T-562 | **SwiftData 새 속성 마이그레이션** | high | completed | 배포 전 검증 |
| T-563 | **전체 기능 테스트** | high | completed | TC-5-63 자동화 완료, 수동 패스 |
| T-564 | **빌드 검증 (0 warnings)** | high | completed | 76 tests ✅ |
| T-565 | **테스트 명세서 작성** | medium | completed | docs/tests/v2.5.6.md |
| T-566 | **PLAN.md 업데이트** | medium | completed | |
| T-567 | **TODO.md 업데이트** | medium | completed | |
| T-568 | **Info.plist 버전 2.5.6** | medium | completed | |

## v2.6.0 — 자체 비디오 플레이어 + 플레이어 모드 설정 (2026-07-20) 🚀

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-600 | **PlayerItem.swift — 모델 생성** | high | completed | |
| T-601 | **NSPlayerView.swift — AVPlayerView wrapper** | high | completed | |
| T-602 | **SubtitleOverlay.swift — 자막 오버레이** | high | completed | |
| T-603 | **SubtitlePanel.swift — 자막 패널** | high | completed | |
| T-604 | **PlayerReducer.swift — TCA reducer** | high | completed | |
| T-605 | **PlayerView.swift — 최종 view + toolbar** | high | completed | |
| T-606 | **Settings: PlayerMode enum + field** | high | completed | |
| T-607 | **SettingsReducer: playerMode state/action** | high | completed | |
| T-608 | **SettingsView: 시스템 탭 picker** | high | completed | |
| T-609 | **Constants: openPlayerWindowNotification** | high | completed | |
| T-610 | **AppDelegate: playerWindow + 핸들러** | high | completed | |
| T-611 | **LibraryReducer: openFile/openSelected 분기** | high | completed | |
| T-612 | **YouTubeDLService: fetchStreamingURL** | high | completed | |
| T-613 | **DiscoverView: 미리보기 버튼** | high | completed | |
| T-614 | **Info.plist 버전 2.6.0** | medium | completed | |
| T-615 | **문서 업데이트 (CHANGELOG, TODO, PLAN)** | medium | completed | |
| T-616 | **빌드 검증** | high | completed | |
| T-617 | **테스트 계획서 작성** | high | completed | |

## v2.6.1 — H.264 우선 다운로드 + 트랜스코딩 캐시 + 호버 컨트롤 (2026-07-20) 🏁

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-618 | **H.264 코덱 필터** — `[ext=mp4][vcodec^=avc1]` 포맷 최우선 선택 | high | completed | |
| T-619 | **기본 해상도 360p** — Constants.defaultResolution 480→360 | high | completed | |
| T-620 | **트랜스코딩 캐시** — transcodedCacheDirectory + SHA256 키 + 캐시 히트/미스 | high | completed | |
| T-621 | **변환 진행률 + ETA** — ffmpeg -progress pipe:1, out_time_us/speed 파싱 | high | completed | |
| T-622 | **자막 언어 우선순위** — `.sorted`로 ko 먼저 배치 | medium | completed | |
| T-623 | **자막 오버레이 기본값 false** — 싱글클릭 토글 (더블클릭 전체화면 유지) | medium | completed | |
| T-624 | **자막 패널 자동 스크롤 버그 수정** — onChange를 ScrollViewReader 레벨로 통합 | medium | completed | |
| T-625 | **플레이어 컨트롤 호버 오버레이** — ZStack 하단 + 3초 auto-hide + onContinuousHover | high | completed | |
| T-626 | **PlayerReducer 확장** — conversionProgress/ETA State + Action | high | completed | |
| T-627 | **전체화면/윈도우 수정** — WindowAccessor, toggleFullscreen, styleMask, collectionBehavior | high | completed | |
| T-628 | **릴리스 v2.6.1 (build 9)** — Info.plist + CHANGELOG | high | completed | |
| T-629 | **문서 업데이트** — PRD/DESIGN/PLAN/TODO/AGENTS | medium | completed | |
| T-630 | **after_move:filepath 경로 검증 fallback** | high | completed | |
| T-631 | **DownloadManager H.264 필터 추가** | high | completed | |
| T-632 | **메뉴바 드롭메뉴 NSView 기반 전환** — attributedTitle → makeQueueMenuItemView | medium | completed | |
| T-633 | **timestamp() DateFormatter 스레드 안전성** — 정적 Formatter + OSAllocatedUnfairLock | high | completed | |
| T-634 | **DownloadManager data race 수정** — ManagerState + stateLock(OSAllocatedUnfairLock) | high | completed | |
| T-635 | **드롭메뉴 NSView 기반 전환** — attributedTitle → makeQueueMenuItemView | high | completed | |
| T-636 | **드롭메뉴 좌우 여백 일치** — menuLeftPadding 19, menuRightPadding 14 | medium | completed | |
| T-637 | **드롭메뉴 너비 축소** — 280→187 | medium | completed | |
| T-638 | **Mock 테스트 target 누락 수정** — target = self 추가 | high | completed | |
| T-639 | **TTSEngine 기본값 변경** — .apple → .edgeTTS (3군데) | medium | completed | |
| T-640 | **문서 업데이트** — CHANGELOG/AGENTS/PLAN/TODO | medium | completed | |

## v2.7.0 — 시스템 언어 + 쿠키 인증 + Whisper AI 자막 + 프리셋 + 히스토리 (2026-07-20) 🔄

### H-2: 시스템 언어 기반 동적 전환 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-700 | **LanguageService 생성** — systemLanguageCode, subtitleLanguages, ttsVoice, appleTTSLanguage, aiPromptLanguage | high | completed | Helpers/LanguageService.swift |
| T-701 | **Settings.subtitleLanguageOverride** — 옵션 + SettingsView picker | medium | completed | |
| T-701a | **DownloadManager.swift** — `--sub-langs` LanguageService 교체 | high | completed | |
| T-701b | **YouTubeDLService.swift** — `--sub-langs` 교체 | high | completed | |
| T-701c | **PlayerReducer.swift** — `--sub-langs` 교체 (시스템 언어 우선) | high | completed | |
| T-701d | **SummarizationService.swift** — `--sub-langs` 교체 | high | completed | |
| T-701e | **LibraryReducer.swift** — `--sub-langs` 교체 | high | completed | |
| T-701f | **TTSService.swift** — AVSpeechSynthesisVoice(language:) 교체 | medium | completed | |
| T-701g | **EdgeTTSClient.swift** — 음성/언어 교체 | medium | completed | LanguageService.ttsVoice(for:) 적용 |
| T-701h | **PodcastService.swift** — 하드코딩 음성 교체 | medium | completed | |

### H-1: 브라우저 쿠키 인증 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-702 | **Settings.cookiesFromBrowser** — 필드 + Picker UI + Common args 반영 | high | completed | |

### H-6: 다운로드 히스토리 (DB) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-703 | **DatabaseManager download_history 테이블** — CREATE + CRUD + DownloadHistoryItem 모델 | high | completed | |
| T-703b | **AppReducer.downloadCompleted** — 히스토리 저장 로직 | high | completed | |
| T-704 | **HistoryView** — 테이블 뷰 + 검색 + 필터 + 우클릭 메뉴 | medium | completed | |
| T-704a | **LibrarySidebarView** — "다운로드 히스토리" 항목 추가 | medium | completed | |

### H-5: 다운로드 프리셋 / Smart Mode ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-705 | **DownloadPreset 모델 + Settings 통합** — presets, activePresetId, smartMode | high | completed | DownloadPreset.swift + Settings 3개 필드 |
| T-706 | **SettingsView 프리셋 편집 UI** — 추가/편집/삭제 | medium | completed | downloads 탭: preset/Smart Mode 행 + 목록 + 삭제 |
| T-707 | **Smart Mode 다운로드 플로우** — 정보 조회 후 프리셋 자동 적용 → 큐 추가 | high | completed | AppReducer.infoResponse에서 activePreset 적용 |

### H-3: AI 자막 생성 (Whisper) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-708 | **Whisper.cpp CLI 번들링** — BundledLibraryManager에 등록 | high | completed | WhisperKit SPM 대신 whisper.cpp CLI 방식 |
| T-709 | **WhisperService** — model download/audio extract/transcribe | high | completed | @unchecked Sendable class, whisper.cpp CLI |
| T-710 | **설정 UI + Settings 필드** — enableWhisperTranscription, whisperModelSize | high | completed | SettingsView Whisper 섹션 |
| T-711a | **PlayerReducer Whisper fallback** | high | completed | transcribeWithWhisper 액션 + SubtitlePanel UI |
| T-711b | **SummarizationService Whisper fallback** | high | completed | fetchTranscript: yt-dlp 실패 → Whisper fallback |
| T-710c | **토스트 알림 독립 컴포넌트** — ToastComponents.swift | medium | completed | ToastMessage/ToastBanner/ToastOverlay + MainView/DownloadQueueView 리팩토링 |

### 문서

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-712 | **문서 업데이트** — CHANGELOG/PLAN/TODO/DESIGN/tests/v2.7.0.md | medium | completed |

## v2.7.1 — 디버그 로그 UI 개선 + 단축키

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-800 | **DebugLogView 자동스크롤 토글** — checkbox → `arrow.down.to.line` image toggle | medium | completed | 자동스크롤 토글 버튼 모양 변경 |
| T-801 | **DebugLogView 하단 버튼 크기 정규화** — `.controlSize(.small)` 제거 | low | completed | 4개 버튼 크기 통일 |
| T-802 | **Cmd+D 단축키 - 디버그 로그** — keyMonitor 감지 + openDebugLogWindow | medium | completed | AppDelegate.swift |
| T-803 | **Cmd+, keyCode 수정** — Space(49) → Comma(43) | high | completed | AppDelegate.swift keyCode 버그 |
| T-804 | **툴바 드롭다운 통합** — 3개 툴바 버튼 → `Menu("영상 다운로드")` | medium | completed | MainView.swift |

## v2.7.2 — 설정 재구성 + 재생 속도 개선

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-805 | **설정 4탭 → 5탭** — 다운로드·저장·알림 신규·시스템·AI | high | completed | SettingsView.swift + SettingsTab enum |
| T-806 | **"채널 업데이트 알림" → "채널 업데이트 확인"** — OFF 시 완전 중단 | high | completed | ChannelUpdateService.swift Combine observer |
| T-807 | **상태바 큐 항목 비활성화 수정** — `action:nil` → `#selector(queueItemNoop)` | high | completed | StatusBarManager.swift |
| T-808 | **채널 체크박스 선택 미초기화** — `addSelectedToQueue()`에서 `selectedIDs` 누락 | high | completed | ChannelContentView.swift |
| T-809 | **첫 재생 지연 단축** — ffprobe → AVURLAsset.loadTracks | high | completed | PlayerView.swift needsTranscoding() |
| T-810 | **codecCache UserDefaults 저장** — 앱 재시작에도 코덱 캐시 유지 | medium | completed | |
| T-811 | **포맷 선택 lower-first 알고리즘** — `Format.best()` exact→lower→higher | high | completed | Format.swift |
| T-812 | **BatchDownloadView 설정 동기화** — selectedResolution 초기값 settings.defaultResolution | medium | completed | |
| T-813 | **ChannelContentView 설정 동기화** — presetResolution 초기값 settings.defaultResolution | medium | completed | |
| T-814 | **상태바 정렬 통일** — idle/완료/상태표시 모두 .right 정렬 | low | completed | |

## v2.7.3 — DMG 배포 + GitHub Releases ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-820 | **DMG 생성 스크립트** — Tools/create_dmg.sh (Applications symlink + Finder 레이아웃) | high | completed | |
| T-821 | **Makefile release 개선** — 빌드→DMG→gh release 통합 | high | completed | |
| T-822 | **build_and_run.sh --no-launch** — release 빌드용 플래그 | medium | completed | |
| T-823 | **DebugLogManager release 호환성** — #if DEBUG 원인으로 release 빌드 실패 수정 | high | completed | |

## v2.7.4 — 코드 서명 + Notarization ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-830 | **Tools/codesign.sh** — Developer ID 서명 + Notarization + Staple + DMG 서명 | high | completed | |
| T-831 | **Makefile codesign/notarize/sign-only/release-signed** 타겟 | medium | completed | |

## v2.7.5 — 자체 업데이트 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-840 | **UpdateChecker.swift** — appcast.json 기반 버전 체크 + 건너뛰기 | high | completed | |
| T-841 | **AppDelegate 업데이트 알림** — 시작 3초 후 체크 → alert | medium | completed | |
| T-842 | **appcast.json** — 최신 버전 메타데이터 (GitHub raw) | medium | completed | |

## v2.7.7 — 오디오 누락 버그 수정 + DebugPanel v1.7 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-860 | **parseFormats combined 우선** — formatMap dedup에서 combined 보호 | high | completed | YouTubeDLService.swift |
| T-861 | **bestaudio[ext=m4a] → bestaudio** — Opus/webm 오디오 배제 문제 수정 | high | completed | YouTubeDLService.swift + DownloadManager.swift |
| T-862 | **채널 다운로더 오디오 누락 근본 수정** — 복합 포맷 선택자 `/best` 분기 래핑 방지 | high | completed | DownloadManager.swift + YouTubeDLService.swift |
| T-863 | **DebugPanel v1.7 전환** — DebugLogLevel 7종, DebugLogEntry, push/clear/formatForAgent | high | completed | DebugLogManager.swift |
| T-864 | **DebugLogView v1.7** — 📌 자동 스크롤, 레벨별 색상, 줄 선택, 복사 | high | completed | DebugLogView.swift |
| T-865 | **NSWindow v1.7 표준** — 600×320 중앙, .floating+100, isReleasedWhenClosed=false | high | completed | AppDelegate.swift |
| T-866 | **Package.swift .define("DEBUG")** — release 빌드 DebugPanel 컴파일 타임 제거 | high | completed | Package.swift |
| T-867 | **build_and_run.sh v1.7 디스패처** — scripts/build-macos.sh 분리, 멀티 플랫폼 | medium | completed | build_and_run.sh |
| T-868 | **Mock/DEBUG 코드 전면 제거** — 모든 뷰/리듀서/액션에서 mock 관련 코드 삭제 | high | completed | 8개 파일 |
| T-869 | **beads/AGENTS.md/codex 정리** — 불필요 파일 삭제, AGENTS.md 전역 설치 | medium | completed | |

## v2.7.6 — 랜딩 페이지 + Buy Me a Coffee ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-850 | **GitHub Pages 랜딩 페이지** — docs/index.html + style.css + app-icon.png | high | completed | |
| T-851 | **Buy Me a Coffee** — 메뉴바 "☕ 후원하기" 항목 + AppDelegate 핸들러 (borasarang) | medium | completed | |


