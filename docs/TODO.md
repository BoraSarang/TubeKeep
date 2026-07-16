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
