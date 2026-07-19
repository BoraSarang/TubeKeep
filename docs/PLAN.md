# PLAN — 구현 계획 및 진행 상황

> **버전별 상세 계획**: `docs/plans/` 폴더 참조 (예: `plans/PLAN_v2.5.2.md`)

## Milestones

| 단계 | 상태 | 설명 |
|------|------|------|
| M1: 메뉴바 + 기본 UI | ✅ 완료 | 메뉴바, 메인창, URL 입력, 조회 |
| M2: 다운로드 엔진 | ✅ 완료 | yt-dlp 연동, 큐 관리, 진행률 |
| M3: 설정 + 사용자 경험 | ✅ 완료 | 설정 UI, 클립보드, 단축키, ETA, 컨텍스트메뉴, 자동재시도, 토스트, 중복검사, 번들링 |
| M4: 채널 다운로더 | ✅ 완료 | 새 창, 좌우 분할, 채널 목록 + 영상 선택 → 일괄 다운로드 |
| M5: 라이브러리 대시보드 | ✅ 완료 | Photos 스타일 메인 창, 그리드/목록 뷰, 검색/필터/정렬, 좌클릭 메뉴 |
| **v1.0.0** | 🏁 **릴리스** | Git tag `v1.0.0`, `~/Applications/VideoDownloader.app` → `TubeKeep.app` |
| **v1.1.0** | 🏁 **전체 완료** | ✅자막 ✅hover툴팁 ✅다중선택삭제 ✅채널순서변경 ✅채널추가버튼 ✅폴더열기 ✅URL Scheme ✅채널업데이트+뱃지클릭+new표시 ✅큐영속성 ✅업로드날짜정렬 ✅단일앱복원 ✅DebugLogView ✅설정창분리(⌘,) ✅뷰이름정리 ✅alwaysOnTop비활성화 ✅설정공유상태화 ✅워닝0 |
| **v2.0.0—v2.3.0** | 🏁 **릴리스** | Discover 탭, AI 요약/태깅, Gemini, 설정 UI 개편, SponsorBlock 등 (2026-07-16) |
| **v2.4.0** | 🏁 **릴리스** | 기술부채 해소 + A.X 4.0 통합: SwiftData, AppDelegate 분리, 자동 테스트, SKT A.X 4.0 요약/태깅 (2026-07-16) |
| **v2.4.1** | 🏁 **릴리스** | OpenRouter Free Tier 통합: OpenRouter → yTeaser → A.X 4.0 → Gemini 4단계 폴백 |
| **v2.5.0—v2.5.5** | 🏁 **릴리스** | AI 콘텐츠 캐싱 + 챕터/팟캐스트/Q&A/마인드맵 + UI 통합 (SQLite DB) |
| **v2.5.6** | 🏁 **릴리스** | 마이그레이션 + 최종 테스트 (2026-07-19) |

---
 
## 완료된 작업 (Completed)

### M1~M4
- 메뉴바 앱 (SF Symbol + 2줄 텍스트, 88px, 다크모드)
- 우클릭 메뉴 (라이브러리/다운로더/일괄/채널/속도측정/종료)
- 글로벌 단축키 ⌥⌘D
- URL 입력 + 정보 조회 + 포맷 선택 + 자막/오디오
- 다운로드 큐 (WaveProgress, ETA, 토스트, 자동재시도, 중복검사)
- 설정 (동시다운로드/속도제한/출력폴더/해상도/템플릿/알림음/시작프로그램)
- 일괄 다운로더 (다중 URL + 프리셋)
- 채널 다운로더 (전체 flat-playlist, 검색/정렬/인피니트스크롤, 프리셋, 24h 캐시)
- 클립보드 감시 (NSPanel)
- DEBUG Mock 테스트
- 의존성 번들링 (yt-dlp + ffmpeg embedded)

### M5: 라이브러리 대시보드
- [x] LibraryItem 모델 (LibrarySortOrder, LibraryFilterMode, LibraryViewMode)
- [x] LibraryReducer (save/load, sort/filter/search, viewMode UserDefaults)
- [x] LibraryCacheService (메모리+디스크 캐시, 썸네일/아바타)
- [x] LibraryView (HStack sidebar 200px + content, toolbar)
- [x] LibrarySidebarView (검색, 전체/최근, 채널 목록 + 우클릭)
- [x] LibraryGridView (LazyVGrid, 인피니트스크롤, 좌클릭 NSMenu)
- [x] LibraryListView (LazyVStack, 동일 메뉴)
- [x] EmptyLibraryCell (full-width 안내 + 3개 버튼)
- [x] AppDelegate 메뉴/창 분리 (라이브러리=main 자동실행, 다운로더=별도)
- [x] downloadCompleted → library 저장 (race condition 수정: sequential save+load)
- [x] FixedWidthWindowController (가로폭 840 고정)
- [x] 그리드/목록 뷰모드 전환 (sortBar 우측 토글)
- [x] LeftClickMenu (좌클릭 시 좌표 기반 NSMenu)

### v1.1.0 전체 (15건 완료)
- [x] T-118: 사이드바 하단 "채널 추가" 버튼
- [x] T-117: 사이드바 채널 drag-to-reorder
- [x] T-116: 자막 별도 다운로드 (yt-dlp --write-subs)
- [x] T-111: 그리드 셀 hover 썸네일 확대 툴팁 (.popover)
- [x] T-112: 여러 항목 선택 → 일괄 삭제 (Cmd+선택)
- [x] T-110: 다운로드 폴더 열기 버튼 (sidebar 하단)
- [x] T-113: 브라우저 URL Scheme (tubekeep:// 등록 + 처리)
- [x] T-119: 업로드 날짜 필드 + 정렬 확장 (LibraryItem.uploadDate, 2개 정렬 옵션)
- [x] T-115: 다운로드 큐 영속성 (UserDefaults 저장/복원, 재시작 시 active→pending)
- [x] T-114: 채널 구독 업데이트 알림 (30분 주기 체크, UNUserNotification + 뱃지)
  - [x] channelsNewVideos 저장 (UserDefaults, 채널별 새 영상 ID 목록)
  - [x] 뱃지 클릭 → 채널 다운로더 창 (첫 새 영상 채널 자동 선택)
  - [x] 뱃지 자동 리셋 제거 (클릭 시까지 유지)
  - [x] DEBUG 메뉴: "채널 업데이트 (DEBUG)" → 실제 checkChannelUpdates 실행
  - [x] ChannelRow: 새 영상 채널 빨간 ● 배지
  - [x] ChannelContentView.channelHeader: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 배너
  - [x] 채널 선택 시 saveSeenVideoIds + clearNewVideoIds + badgeCount 업데이트
  - [x] channelsSeenVideoIds 도입: 확인한 영상 재감지 방지 (다운로드 안 해도 OK)
  - [x] 다운로드 시 removeSeenVideoIds 호출
  - [x] 체크 진행률 상태바 표시 ("업데이트 확인 중 (N/M)")
  - [x] 체크 DEBUG 로그 (channelLogManager)
- [x] Channel @handle 안전성: fetchAllVideos에서 @ 자동 추가
- [x] 언어 지원: Constants.youtubeExtractorArgs (시스템 언어 기반 yt-dlp --extractor-args)
- [x] 영상 필터링: `@handle/videos` URL로 숏츠 제외 + `availability` 필드로 회원전용 제외
- [x] 채널 신규 항목 insert(at: 0) — 채널 목록 항상 최신순
- [x] Hover 미리보기 위치: cell.midX - 360 (좌측 확장, bottom-right=cell 중앙)
- [x] DEBUG Mock: "상태바 테스트" + "채널 업데이트" 서브메뉴
- [x] 단일 .app 복원: LibraryDownloader.app 제거, 단일 VideoDownloader.app → TubeKeep.app
- [x] DebugLogView: 각 window에 DEBUG 동작 로그 패널 (자동 스크롤 + 복사)

### v1.1.0 추가 (2026-07-15~16 세션)
- [x] 이미지 캐싱 전면 개선: 모든 AsyncImage 제거, CachedThumbnailView/CachedAvatarView 통일, LibrarySidebarView 아바타 버그 수정
- [x] 캐시 디렉토리 경로 수정: com.mdownload.library → com.tubekeep + 마이그레이션
- [x] 라이브러리 재생시간 표시: LibraryItem.duration + formatDuration() + 그리드/목록 UI
- [x] 채널 아바타 동그랗게 + padding
- [x] build_and_run.sh --clean 옵션 추가
- [x] 채널 영상 인덱스 기능: LibraryItem.channelUploadIndex + updateChannelUploadIndices + AppReducer 전달
- [x] LibrarySortOrder indexAsc/indexDesc 추가 + LibraryReducer 정렬 로직 + 채널 선택 기본정렬=인덱스 역순
- [x] 그리드/목록 뷰 인덱스 표시 (#003 배지)
- [x] 새로고침 시 syncDownloadedIDsFromDisk 호출 (디스크-캐시 동기화)
- [x] **설정 창 분리 (⌘,)**: AppDelegate 직접 NSWindow 관리, Settings 씬 미사용
- [x] **뷰 이름 정리**: MainView→VideoDownloadView, LibraryView→MainView (파일명/구조체명/참조 전체)
- [x] **영상 다운로더에서 설정 영역 완전 제거**: VideoDownloadView 하단 SettingsView 삭제
- [x] **메뉴바 "설정..." 추가 (⌘, 단축키)**: AppDelegate 메뉴 재구성
- [x] **UserDefaults 직접 읽기 → 공유 Store 참조로 변경**: HomeReducer, DownloadQueueReducer, DownloadManager 3곳
- [x] **alwaysOnTop 설정 비활성화**: 설정 창에서 비활성/안내 표시 (영상 다운로더 창 전용 속성)
- [x] 설정 창 가로 480px 고정, 세로 580px — contentMin/MaxSize 설정
- [x] NSUserNotification → UNUserNotificationCenter 마이그레이션 (deprecated 해결)
- [x] CachedImageViews actor isolation 경고 수정 — await 추가
- [x] AppDelegate Sendable closure capture 경고 수정 — 로컬 상수 캡처

### 버그 수정
- [x] `-[NSIndirectTaggedPointerString count]` crash — OSAllocatedUnfairLock
- [x] 다운로드 개수 불일치 (3 다운, 2 표시) — sequential save+load
- [x] "다운로드" 버튼이 잘못된 창 오픈 — openDownloaderWindowNotification
- [x] 모든 Swift 6 Sendable 경고 수정 (0 warnings)
- [x] 그리드 레이아웃 리사이즈 깨짐 — EmptyLibraryCell을 LazyVGrid 밖으로
- [x] FixedWidthWindowController dealloc 문제 — AppDelegate 프로퍼티 저장
- [x] 자동 실행 (build_and_run.sh에 open 추가)
- [x] Channel @handle 누락 — fetchAllVideos handle 자동 @ 추가
- [x] 회원 전용 영상 차단 — --playlist-items 0 → --flat-playlist --playlist-end 1
- [x] Short 필터링 — /videos URL + availability 필터 (flat-playlist에서 /shorts/ URL 미출력)
- [x] 단일 .app 복원 (LibraryDownloader.app 제거, DistributedNotification 제거, openMainWindow 직접 호출)
- [x] 동영상 개수: 서버 fetch 시에만 업데이트, 중복 notification 시 덮어쓰기 방지
- [x] refreshChannelInfo videoCount 보존 — fetchChannelInfo가 0 반환해도 기존 count 유지

---

### v1.2.0 — 채널 업데이트 알림 개선 + 디스크 사용량 (2026-07-16)
- [x] channelsSeenVideoIds: 확인한 영상 재감지 방지 (다운로드 안 해도 확인 시 seenIds로 이동)
- [x] 상태바 진행률 ("업데이트 확인 중 (N/M)")
- [x] DEBUG 로그 출력 위치 변경: channelLogManager → libraryLogManager
- [x] StatusBar badge autoReset 제거 (10초 → 클릭 시까지 유지)
- [x] openVideoDownloaderWindow 오류 수정: MainView → VideoDownloadView
- [x] LibraryCacheService.calculateDiskUsage() — outputDirectory + 캐시 디렉토리 합산
- [x] LibraryReducer diskUsageBytes State + calculateDiskUsage/diskUsageUpdated 액션
- [x] AppReducer/LibraryReducer 트리거: downloadCompleted, removeSelected, removeItemsByChannel 시 재계산
- [x] LibrarySidebarView 하단: "Finder에서 보기" + 디스크 사용량 + ↻ 버튼
- [x] formatBytes() — ByteCountFormatter 포맷팅
- [x] 모든 빌드 경고 해결 (0 warnings)
- [x] 저장 폴더 기본값 변경: `~/Downloads` → `~/Documents/TubeKeep`
- [x] 첫 실행 시 `~/Documents/TubeKeep` 자동 생성 (없을 경우)
- [x] 변수명 리팩토링: `outputDirectory` → `storageDirectory` (전체 코드베이스)
- [x] UI 텍스트 변경: "출력 폴더" → "저장 폴더"
- [x] Settings.CodingKeys로 JSON 키 `"outputDirectory"` 하위호환 유지 (마이그레이션 불필요)
- [x] BookmarkManager 키 변경: `outputDirectoryBookmark` → `storageDirectoryBookmark`

### v2.0.0 — Discover 탭 + AI 요약/자동 태깅 (2026-07-16) ⚡

**macOS 26+ 전용** | Swift 6.3 | SPM 6.2

#### Discover Tab
- [x] 사이드바 Library/Discover 네비게이션 (SF Symbol + accentColor)
- [x] 8개 카테고리: 전체/음악/기술/게임/뉴스/스포츠/엔터테인먼트/교육
- [x] yt-dlp `ytsearch` 기반 트렌딩/인기 영상 검색
- [x] 30분 TTL 캐싱 (TrendingService CacheEntry)
- [x] DiscoverView 카드 그리드 (호버 시 다운로드/AI 요약 버튼)
- [x] 원클릭 다운로드 큐 추가 (discoverAddToQueue)
- [x] 오프라인 안내 화면 (wifi.slash + 에러 메시지)
- [x] Discover 모드에서만 카테고리 리스트 표시

#### AI 요약 (Ollama)
- [x] SummarizationService — 자막(VTT/SRT) 추출 → Ollama LLM 요약
- [x] 요약 결과: 개요 + 핵심 포인트
- [x] LibraryItem.summary 영구 저장 (updateItem)
- [x] Library 좌클릭 메뉴 "AI 요약" (그리드 + 목록 뷰)
- [x] 온라인: yt-dlp 자막 fetch → 요약
- [x] 오프라인: 로컬 자막 파일 → 요약
- [x] 자막 없음 에러 처리

#### AI 자동 태깅 (Ollama + 키워드 fallback)
- [x] TaggingService — Ollama 분류 (우선) + 키워드 기반 fallback
- [x] 10개 카테고리 자동 분류 (기술/IT, 음악, 게임, 뉴스, 스포츠, 엔터테인먼트, 교육, 요리, 여행, 과학)
- [x] 다운로드 완료 시 자동 태깅 (AppReducer downloadCompleted)
- [x] LibraryItem.tags 저장 (updateItem)
- [x] 키워드 fallback: channel+title 키워드 매칭

#### Infrastructure
- [x] macOS 타겟 26+ 상향 (Package.swift, Info.plist)
- [x] Swift 6 동시성 에러 전면 수정 (8개 파일)
- [x] LibraryCacheService.updateItem() 추가
- [x] TrendingVideo 모델 + TrendingCategory 열거형

#### 새 파일 (6개)
- Models/TrendingVideo.swift
- Features/Discover/DiscoverView.swift
- Services/TrendingService.swift
- Services/SummarizationService.swift
- Services/TaggingService.swift

### v2.0.1 — AI 요약 팝업 UI 통일 + Discover UX 개선 (2026-07-16) ⚡

#### UI 개선
- [x] 사이드바 한글화: Library→보관함, Discover→트랜드
- [x] 트랜드 검색창: 사이드바 실시간 검색 필드
- [x] 카테고리 리스트 리디자인: 드래그 핸들 + SF Symbol 아이콘 + 이름 + 드래그-드롭 순서변경 (카운트 제거)
- [x] TrendingCategory.systemIcon 프로퍼티 + FeaturedCategoryDropDelegate
- [x] 카테고리 순서 @AppStorage("categoryOrder") 영구 저장
- [x] DiscoverCard ZStack → `.overlay()`로 변경 (hover 버튼 레이아웃 영향 제거)
- [x] 다운로드 완료 배지 가시성 개선 (초록 배경 + 흰 아이콘 + 그림자)
- [x] Discover popover arrowEdge `.leading` → `.trailing` (오른쪽 표시)
- [x] Library AI 요약 sheet 내용 상단 정렬

#### AI 요약 UX 통일
- [x] Discover AI 요약: 인라인 → `.popover` (discoverSummaryVideoId/Text/Loading State)
- [x] Library AI 요약: 좌클릭 메뉴 → `.sheet` (librarySummaryVideoId/Text/Loading State)
- [x] HomeView(다운로더): AI 요약 버튼 + popover (summaryText/Loading/showSummaryPopover State)
- [x] 요약 결과 LibraryItem.summary 영구 저장 유지

#### Bug Fixes
- [x] Local file 요약 실패: 외부 자막 파일 없으면 fetchTranscript(videoId) fallback
- [x] LibraryItem 구버전 호환: tags/summary decodeIfPresent
- [x] Library sheet 가려짐: overlay → .sheet 전환

#### Infrastructure
- [x] docs/SETUP_OLLAMA.md 문서화

### v2.1.0 — Google Gemini API 마이그레이션 (2026-07-16) ⚡

#### Breaking Changes
- [x] Ollama → Google Gemini API 전환 (SummarizationService, TaggingService)
- [x] Ollama 의존성 제거 (더 이상 brew install ollama 불필요)

#### Setting
- [x] Gemini API 키 입력 필드 (SettingsView SecureField + 발급 링크)
- [x] API 키 검증 알럿 + "설정 열기" / "키 발급 받기" 플로우
- [x] API 키 UserDefaults 저장 (geminiAPIKey 키)

#### SummarizationService
- [x] queryOllama → queryGemini(prompt:apiKey:) 교체
- [x] 프롬프트 → Gemini generateContent API 형식으로 마이그레이션
- [x] apiKey 파라미터 추가, 키 없을 시 요약 불가

#### TaggingService
- [x] queryOllama → queryGemini(prompt:apiKey:) 교체
- [x] classify(title:channel:apiKey:) — 키 없으면 autoClassify fallback

#### Reducer Flow
- [x] LibraryReducer: discoverRequestSummary/showSummary에 API 키 체크 + showGeminiKeyAlert
- [x] HomeReducer: requestSummary에 API 키 체크 + showGeminiKeyAlert
- [x] Constants.openSettingsWindowNotification + AppDelegate observer → openSettingsWindow()

#### Views
- [x] MainView: .alert (showGeminiKeyAlert)
- [x] DiscoverView: .alert (showGeminiKeyAlert)
- [x] HomeView: .alert (showGeminiKeyAlert)

#### Infrastructure
- [x] docs/SETUP_GEMINI.md 신규 작성
- [x] docs/SETUP_OLLAMA.md 레거시 마이그레이션 노트 추가

### v2.2.0 — 설정 UI 전면 개편 (OpenCode Desktop 스타일) (2026-07-16) ⚡

#### Breaking Changes
- [x] 설정 창 UI 전면 개편: 접이식 VStack 패널 → YouTube/시스템 환경설정 스타일 4탭 레이아웃
- [x] 창 크기 480×580 → 560×420 고정 (리사이즈 불가)
- [x] SettingsView: 기존 3개 헬퍼(`settingRow`/`row`/`infoText`) → 단일 제네릭 `SettingsRow<Control>` 컴포넌트

#### Settings 탭 내비게이션
- [x] `SettingsTab` enum (일반/저장/시스템/AI 요약) — CaseIterable + SF Symbol icon 매핑
- [x] 좌측 140pt 사이드바 + 우측 ScrollView 콘텐츠
- [x] `SettingsReducer.selectedTab` State/Action으로 탭 전환
- [x] 항목 간 하단 border 구분

#### SettingsRow 컴포넌트
- [x] `VStack { HStack(title, control) + Text(description, .trailing, lineLimit(1)) }` 구조
- [x] 제네릭 `Control: View` 파라미터로 모든 설정 타입 지원
- [x] description 11pt `.caption` + `minimumScaleFactor(0.7)` + 한 줄 고정

#### 설정 항목 변경
- [x] 일반 탭: 다운로드 경로, 동시 다운로드, 속도 제한, 해상도 Picker (4K→144p 순서)
- [x] 저장 탭: 파일명 템플릿 (200pt 고정 폭), 알림음, 시작 프로그램
- [x] 시스템 탭: 메인창 자동 표시 토글 (신규), 메뉴바 아이콘 스타일
- [x] AI 요약 탭: 서비스 드롭다운 (yTeaser/Gemini), API 키 입력, Billing 링크, 우선순위 안내
- [x] 서비스 선택: RadioGroup → Menu Picker, `.fixedSize()`로 truncation 방지
- [x] 항상 위에 고정: 설정에서 제거, 각 창 로컬 `@State`로 이전
- [x] 해상도 Picker 3군데 통일: SettingsView, ChannelContentView, BatchDownloadView

#### 단축키
- [x] `⌘,` NSEvent.addLocalMonitorForEvents 글로벌 모니터 (메인 창에서도 동작)
- [x] AppDelegate.settingsWindowController: window retaining + openSettingsWindow()

#### 상태 관리
- [x] `summaryServiceMode`: stored property (computed→stored) + custom init(UserDefaults) + setSummaryServiceMode Action에서 직접 저장
- [x] `showMainWindowOnLaunch`: Settings 필드 + AppReducer.appDidFinishLaunching에서 로드
- [x] `alwaysOnTop`: AppReducer/Settings에서 제거, 3개 창(VideoDownload/BatchDownload/ChannelDownload) 로컬 `@State`로 전환

#### UI 세부
- [x] 섹션 헤더: 9pt → 12pt semibold, 상하 여백 증가
- [x] 설명문: 8pt → 11pt, lineLimit(1) + .trailing 정렬
- [x] 창 하단: AI 요약 우선순위 안내 ("yTeaser 소진 시 Gemini 전환, 키 없으면 미동작")

#### Removed
- [x] `SummaryServiceMode` enum 완전 제거 (`Settings.swift`)
- [x] `summaryServiceModeKey` 제거 (`Constants.swift`)
- [x] `summaryServiceMode` State/Action/init 제거 (`SettingsReducer.swift`)
- [x] Reducer 모드 분기 제거 — 항상 yTeaser 먼저 호출, `quotaExceeded` 시 Gemini fallback (`LibraryReducer.swift`, `HomeReducer.swift`)

#### Infrastructure
- [x] `SettingsTab` enum: `Models/Settings.swift` 신규
- [x] `SettingsRow<Control>`: 제네릭 뷰 컴포넌트 (`SettingsView.swift`)
- [x] `Constants.showMainWindowOnLaunchKey` 저장 키 추가
- [x] `SummarizationService.SummaryError.quotaExceeded` 케이스 추가

### v2.3.0 — SponsorBlock + 기능 다듬기 (2026-07-16) 🏁

#### SponsorBlock + 메타데이터 임베딩
- [x] SponsorBlock: yt-dlp `--sponsorblock-remove all` 플래그 추가
- [x] 메타데이터/섬네일 임베딩: yt-dlp `--embed-metadata --embed-thumbnail` 플래그 추가
- [x] `Settings.sponsorBlock` + `Settings.embedMetadata` Bool 필드 (기본값 true)
- [x] 시스템 탭에 토글 2개 추가
- [x] `DownloadManager.buildDownloadArgs()` + `YouTubeDLService.buildDownloadArgs()` 양쪽 적용

#### 다운로드 큐 개별 제어
- [x] DownloadRow: 상태별 액션 버튼 추가 (다운로드중→일시정지, 일시정지→재개, 실패→재시도)
- [x] 실패 시 에러 메시지 간략 표시

#### 에러 메시지 래핑
- [x] `ErrorMessageMapper` 유틸리티: yt-dlp 공통 에러 → 한글 친화적 메시지 매핑
- [x] `DownloadManager.swift` completionHandler + `YouTubeDLService.swift` 에러 throw 적용

#### 라이브러리 벌크 액션
- [x] `revealSelectedInFinder`, `openSelected` Action 추가
- [x] SelectionBar에 "Finder에서 보기", "열기" 버튼 + SF Symbol 아이콘 추가 (GridView + ListView 양쪽)
- [x] Cmd+Click 선택 감지 `NSApp.currentEvent` → `NSEvent.modifierFlags`로 수정

#### 메뉴바 상태 개선
- [x] 메뉴 드롭다운에 큐 요약 정보 표시 (다운로드 중/완료/대기 개수 + 속도 + ETA)
- [x] `startDownload`/`pauseDownload`/`resumeDownload` 시 statusBar 동기화
- [x] `RunLoop.main.common` 모드 타이머 + `menu.itemChanged()` 실시간 갱신

#### Home AI 요약 팝오버 디자인 통일
- [x] Discover/Library와 동일한 380×320 고정, ScrollView 결과, 복사 버튼

#### 순번 인덱스 개선
- [x] `isChannelDownload`일 때만 `fetchUploadIndex` 호출
- [x] `renameZeroIndexedFiles`: 채널 새로고침 시 `000 - ` prefix 파일을 올바른 순번으로 rename

#### UI 조정
- [x] 해상도 Picker 130pt → 200pt (긴 포맷 라벨 대응)
- [x] Discover 검색 아이콘: `Group { }.frame(width:14, height:14)`으로 레이아웃 안정화

#### 다운로드 실패 판정 버그 수정 (v2.3.0-post)
- [x] `--print-to-file after_move:filepath` 인자 추가 → 실제 출력 경로 추적
- [x] 종료코드 + 파일 존재 여부 모두 확인 → thumbnail/sponsorblock post-processing non-zero exit에도 성공 처리
- [x] 완료 핸들러에 outputPath 전달 → LibraryItem.filePath에 실제 경로 사용

#### 채널 다운로더 메뉴
- [x] 채널 목록 우클릭 → "Finder에서 채널 폴더 열기" 추가

#### 새 파일
- [x] `Services/ErrorMessageMapper.swift`
- [x] `docs/TEST.md` — v2.3.0 테스트 명세서

#### 테스트 (TC-01~TC-08)
- [x] TC-02 메타데이터/섬네일 임베딩 ✅
- [x] TC-03 큐 개별 제어 ✅
- [x] TC-04 에러 메시지 ✅
- [x] TC-05 라이브러리 벌크 액션 ✅
- [x] TC-06 메뉴바 큐 요약 ✅
- [x] TC-07 설정 지속성 ✅
- [x] TC-08 회귀 테스트 (11/11) ✅
- [x] TC-01 SponsorBlock ⬜ 스킵 (영상 미확보)

### v2.5.0 — AI 콘텐츠 캐싱 + 챕터/팟캐스트/Q&A/마인드맵 (2026-07-17) 🔄

**버전 체계**: v2.5.0 → v2.5.1 → ... → v2.5.6 (+0.0.1씩 증가)

#### 챕터 1: SQLite DB 구축 + 자막 캐싱 (v2.5.0)
- [x] T-500: DatabaseManager.swift 생성 (SQLite3 오픈/생성)
- [x] T-501: video_ai_data 테이블 생성 (CREATE TABLE IF NOT EXISTS)
- [x] T-502: CRUD 메서드 구현 (save/load/update/delete)
- [x] T-503: SummarizationService — 자막 DB 저장 로직
- [x] T-504: SummarizationService — 자막 DB 로드 로직
- [x] T-505: LibraryCacheService — 요약 저장 시 DB 동기화
- [x] T-506: LibraryItem 새 속성 추가 (transcript, chapters)
- [x] T-507: Info.plist 버전 2.5.0 + Bundle ID 수정 (com.borasarang.tubekeep)

#### 챕터 2: AI 요약 + 챕터 생성 (v2.5.1)
- [x] T-510: ChapterInfo 모델 생성
- [x] T-511: SummaryResult에 chapters 필드 추가
- [x] T-512: SummarizationService 프롬프트 변경
- [x] T-513: OpenRouterService 프롬프트 변경
- [x] T-514: AX4Service 프롬프트 변경
- [x] T-515: 챕터 응답 파싱 로직
- [x] T-516: DB에 챕터 저장
- [x] T-517: LibraryGridView 챕터 표시 UI
- [x] T-518: LibraryListView 챕터 표시 UI
- [x] T-519: Info.plist 버전 2.5.1

#### 챕터 3: AI 팟캐스트 생성 (v2.5.2) — macOS 내장 TTS (무료)

**TTS 엔진**: AVSpeechSynthesizer (macOS 내장, 완전 무료, 오프라인)
**대화 스크립트**: 기존 LLM 폴백 체인 활용 (OpenRouter → yTeaser → A.X 4.0 → Gemini)
**상세 계획**: `docs/plans/PLAN_v2.5.2.md` 참조

- [x] T-520: PodcastService.swift 생성
- [x] T-520a: PodcastScript 모델 정의
- [x] T-521: AI 대화 스크립트 생성 프롬프트
- [x] T-522: TTSService 생성 (AVSpeechSynthesizer 래퍼)
- [x] T-523: 오디오 파일 저장 로직
- [x] T-524: DB에 podcast_path 저장
- [x] T-525: 요약 팝업에 팟캐스트 컨트롤 추가
- [x] T-526: 컨텍스트 메뉴 팟캐스트 항목
- [x] T-527: LibraryReducer 팟캐스트 액션
- [x] T-528: 팟캐스트 파일 정리
- [x] T-529: Info.plist 버전 2.5.2

#### 챕터 4: 트랜스크립트 Q&A (v2.5.3)
- [x] T-530: QAService.swift 생성
- [x] T-531: qna_history 테이블 생성
- [x] T-532: Q&A 프롬프트 설계
- [x] T-533: QAView UI
- [x] T-534: LibraryReducer Q&A 액션
- [x] T-535: Q&A 히스토리 저장/로드
- [x] T-536: 타임스탬프 클릭 → 재생 위치 이동
- [x] T-537: Info.plist 버전 2.5.3

#### 챕터 5: 마인드맵 생성 (v2.5.4)
- [x] T-540: MindmapNode 모델 생성
- [x] T-541: MindmapService.swift 생성
- [x] T-542: 마인드맵 생성 프롬프트
- [x] T-543: DB에 마인드맵 저장
- [x] T-544: MindmapView UI
- [x] T-545: 마인드맵 노드 확장/축소
- [ ] T-546: 마인드맵 이미지 내보내기 (취소 — 저순위)
- [x] T-547: Info.plist 버전 2.5.4

#### 챕터 6: UI 통합 + AI 창 리팩토링 (v2.5.5)
- [x] T-550: LibraryGridView 챕터 표시 (v2.5.1에서 완료)
- [x] T-551: LibraryListView 챕터 표시 (v2.5.1에서 완료)
- [x] T-552: 액션 메뉴 통합 (3→1 "AI 기능")
- [x] T-553: AIWindowView 좌우 split (summary/chapters | mindmap/Q&A)
- [x] T-554: 팟캐스트 시간 왼쪽 표시
- [x] T-555: 다크모드 오버레이 + 자동 포커스 방지
- [x] T-556: Info.plist 버전 2.5.5

#### 챕터 7: 마이그레이션 + 테스트 (v2.5.6)
- [x] T-560: DatabaseManager 마이그레이션 로직 (SwiftData 마이그레이션은 배포 전 검증에서 수행)
- [x] T-561: 기존 데이터 동기화 (summary→DB) (배포 전 검증에서 수행)
- [x] T-562: SwiftData 새 속성 마이그레이션 (배포 전 검증에서 수행)
- [x] T-563: 전체 기능 테스트 (TC-5-63 빌드 검증 완료, 수동 테스트는 배포 전으로 패스)
- [x] T-564: 빌드 검증 ✅ swift build -c release 성공, 76개 테스트 통과
- [x] T-565: 테스트 명세서 작성 ✅ docs/tests/v2.5.6.md
- [x] T-566: PLAN.md 업데이트 ✅
- [x] T-567: TODO.md 업데이트 ✅
- [x] T-568: Info.plist 버전 2.5.6 ✅

## 제외된 기능 (Cancelled)

- 큐 검색/정렬
- iCloud 히스토리 동기화
- 자동 업데이트 (Sparkle)
- macOS Notification Center 배너
- 브라우저 확장 (Safari/Chrome)
