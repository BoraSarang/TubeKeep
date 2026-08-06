# DESIGN — 기술 설계 문서

## 1. 아키텍처 개요

- **UI**: SwiftUI (macOS 14+)
- **아키텍처**: TCA 1.10 (The Composable Architecture)
- **백엔드**: yt-dlp (Process 호출)
- **메뉴바**: 순수 AppKit (NSStatusBar + NSView)
- **SPM** 모듈, swift-tools-version: 6.2, Swift 5 언어 모드
- **단일 .app**: `TubeKeep.app` (LSUIElement, com.borasarang.tubekeep)
- **지원 칩셋**: Apple Silicon (ARM64) 전용
- **런타임 의존성**: ffmpeg + yt-dlp (앱 번들 `Contents/Resources`에 포함, 번들 우선 → brew → PATH 순서)
- **영구 저장소**: SQLite (AI 데이터), SwiftData (라이브러리 항목/채널), UserDefaults (설정/캐시)
- **설정 창**: `AppDelegate.openSettingsWindow()`로 NSWindow 직접 관리 (`TubeKeepApp`은 빈 Scene), ⌘, 단축키 지원

```
┌─────────────────────────────────────────┐
│              AppDelegate                │
│  NSStatusBar / NSWindow x5 / NSPanel  │
│  글로벌단축키 / 클립보드감시  │
└────────────────┬────────────────────────┘
                 │ Store(initialState:) { AppReducer() }
                 ▼
┌─────────────────────────────────────────┐
│              AppReducer                 │
│  Scope: home / downloadQueue / settings │
│         / statusBar / library           │
│  Reduce: 브릿지 로직 (상태 동기화)       │
└─────────────────────────────────────────┘
```

---

## 2. Reducer 상세

### 2.1 AppReducer

#### State
```swift
@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var home = HomeReducer.State()
        var downloadQueue = DownloadQueueReducer.State()
        var settings = SettingsReducer.State()
        var statusBar = StatusBarReducer.State()
        var library = LibraryReducer.State()
    }
}
```

#### Action
```swift
enum Action: Equatable {
    case home(HomeReducer.Action)
    case downloadQueue(DownloadQueueReducer.Action)
    case settings(SettingsReducer.Action)
    case statusBar(StatusBarReducer.Action)
    case library(LibraryReducer.Action)
    case clipboardDetected(String)
    case appDidFinishLaunching
    case discoverAddToQueue(DownloadItem)
}
```

#### 브릿지 로직
- `appDidFinishLaunching` → UserDefaults에서 설정 로드, DebugLogManager 초기화, 키보드 단축키 모니터 등록
- `downloadQueue(.downloadCompleted(id:, success:, outputPath:))` → LibraryItem 생성/저장 → `.library(.loadFromDisk)` 재로드
- `downloadQueue(.addToQueueResponse(id:))` → 여유 슬롯이 있으면 `startDownload` 디스패치
- `playlistSelection(.confirmSelection)` → 선택 항목 일괄 추가
- `downloadQueue(.updateProgress)` / `downloadQueue(.removeItem)` 등 → statusBar 동기화
- `settings(.setConcurrentDownloads)` → downloadQueue.maxConcurrent 동기화
- `discoverAddToQueue(DownloadItem)` → 중복 검사 후 downloadQueue.addItems 전송 (채널 인덱스 포함)
- `clipboardDetected(String)` → 라이브러리 창 상태에 따라 NSPanel 팝오버 또는 다운로더 창 오픈

### 2.2 HomeReducer (VideoDownloadView)

```swift
@ObservableState
struct State: Equatable {
    @Presents var playlistSelection: PlaylistSelectionReducer.State?
    var urlString: String = ""
    var isFetching: Bool = false
    var fetchStartTime: Date?
    var fetchLogs: [String] = []
    var videoInfo: VideoInfo?
    var availableFormats: [Format] = []
    var selectedFormatId: String?
    var includeSubtitles: Bool = false
    var audioOnly: Bool = false
    var errorMessage: String?
    var lastAutoFetchedURL: String = ""

    // v2.0.1: AI 요약 (다운로더)
    var summaryText: String?
    var summaryLoading = false
    var showSummaryPopover = false
}
```

**CancelID**: `.fetch`, `.fetchTimer`

#### v2.0.1 추가 Action
```
toggleSummaryPopover / summaryLoaded(String) / summaryFailed(String) / dismissSummary
```

### 2.3 DownloadQueueReducer

```swift
@ObservableState
struct State: Equatable {
    var items: IdentifiedArrayOf<DownloadItem> = []
    var maxConcurrent: Int = 2
    var maxRetries: Int = 3
    var outputDirectory: String = "~/Downloads"
    var filenameTemplate: String = "{channel} - {index} - {title}"
    var toastMessage: ToastMessage?
}
```

주요 액션: `addItem(s)`, `startAll/stopAll/startDownload/pauseDownload/resumeDownload`, `retryDownload/retryAttempt`, `removeItem`, `updateProgress`, `downloadCompleted`, `showToast/dismissToast`, `revealInFinder`, `clearCompleted/clearAll`, `setMaxConcurrent/Retries`.

### 2.4 SettingsReducer

```swift
@ObservableState
struct State: Equatable {
    var selectedTab: SettingsTab = .general

    // General
    var concurrentDownloads: Int = 2
    var storageDirectory: String = "~/Documents/TubeKeep"
    var defaultResolution: Int = 360
    var maxRetries: Int = 3
    var limitRate: Int = 0

    // Storage
    var filenameTemplate: String = "{channel} - {index} - {title}"
    var playSoundOnComplete: Bool = true
    var launchAtLogin: Bool = false

    // System
    var showMainWindowOnLaunch: Bool = false
    var clipboardMonitoring: Bool = true
    var maxUploadCheck: Int = 500
    var skipIndexOnFailure: Bool = false
    var playerMode: PlayerMode = .builtIn

    // AI (v2.2.0: SummaryServiceMode 제거, 항상 자동 폴백)
    var geminiAPIKey: String = ""
    var openRouterAPIKey: String = ""
    var ax4APIKey: String = ""

    var sponsorBlock: Bool = true           // v2.3.0
    var embedMetadata: Bool = true          // v2.3.0
}
```

저장: UserDefaults JSON (`appSettings` 키).
- `AppReducer`가 전역 공유 상태(`state.settings`)로 관리 → 모든 기능에서 즉시 반영
- `DownloadQueueReducer`에 `storageDirectory`, `filenameTemplate` 동기화 필드 추가
- `DownloadManager`에 `updateSettings` 시 별도 캐싱 (`storageDirectory`, `filenameTemplate`)

### 2.5 StatusBarReducer

```swift
struct State: Equatable {
    var statusText = "대기 중"
    var downloadSpeed = ""
    var badgeCount = 0
    var hasActiveDownloads = false
    var activeCount = 0
    var totalCount = 0
    var completedCount = 0
    var downloadETA = ""
}
```

### 2.6 LibraryReducer

#### State
```swift
@Reducer
struct LibraryReducer {
    @ObservableState
    struct State: Equatable {
        var items: [LibraryItem] = []
        var searchText = ""
        var selectedChannel: String? = nil
        var sortOrder: LibrarySortOrder = .dateDesc
        var filterMode: LibraryFilterMode = .all
        var viewMode: LibraryViewMode = .grid
        var isLoading = false
        var selectedIds: Set<String> = []
        var subtitleDownloadingIds: Set<String> = []
        var subtitleAvailableIds: Set<String> = []
        var summaryAvailableIds: Set<String> = []
        var diskUsageBytes: Int64 = 0

        // Navigtion
        var sidebarMode: LibrarySidebarMode = .library

        // Discover (v2.0.0)
        var discoverCategory: TrendingCategory = .all
        var discoverVideos: [TrendingCategory: [TrendingVideo]] = [:]
        var discoverLoading = false
        var discoverError: String?
        var discoverSearchText = ""
        var discoverSearchResults: [TrendingVideo] = []
        var discoverSearching = false

        // Discover Summary (v2.0.1)
        var discoverSummaryVideoId: String?
        var discoverSummaryText: String?
        var discoverSummaryProvider: String?
        var discoverSummaryLoading = false

        // Library Summary (v2.0.1)
        var librarySummaryVideoId: String?
        var librarySummaryText: String?
        var librarySummaryProvider: String?
        var librarySummaryLoading = false

        // Podcast (v2.5.2)
        var podcastGeneratingIds: Set<String> = []
        var podcastPlayingId: String?
        var podcastError: String?
        var podcastAvailableIds: Set<String> = []
        var podcastLastEngine: String?

        // Q&A (v2.5.3)
        var qnaHistoryItems: [QAHistoryItem] = []
        var qnaLoading = false
        var qnaError: String?
        var qnaSelectedVideoId: String?
        var qnaShowSheet = false

        // Mindmap (v2.5.4)
        var mindmapNode: MindmapNode?
        var mindmapLoading = false
        var mindmapError: String?
        var mindmapShow = false

        // Gemini API Key Alert
        var showGeminiKeyAlert = false
    }
}
```

#### Action
```
loadFromDisk / itemsLoaded / addItem / removeItem / removeItemsByChannel / removeSelected
revealSelectedInFinder / openSelected
setSearchText / setSelectedChannel / setSortOrder / setFilterMode / setViewMode
openFile / revealInFinder
downloadSubtitles / subtitleResult / dismissSubtitleToast        // T-116: 자막 다운로드
toggleSelection / selectAll / clearSelection  // T-112: 다중 선택
calculateDiskUsage / diskUsageUpdated         // 디스크 사용량
openChannelDownload(channelId:channelName:)   // 채널 다운로더 열기

// Discover (v2.0.0/v2.0.1)
setSidebarMode / selectDiscoverCategory / fetchTrending
trendingLoaded / trendingFailed / refreshTrending
setDiscoverSearchText / discoverSearch / discoverSearchLoaded / discoverSearchFailed
discoverRequestSummary / discoverSummaryLoaded / discoverSummaryFailed
discoverDismissSummary

// Summary (v2.5.0/v2.5.1)
showSummary / resummarize
summaryResult(videoId:overview:keyPoints:chapters:provider:)
summaryFailed / dismissLibrarySummary

// Tagging (v2.0.0)
tagItem / itemTagged

// Podcast (v2.5.2)
generatePodcast / podcastScriptResult / podcastFailed
playPodcast / podcastPlaybackUpdate / stopPodcast / deletePodcast
setPodcastEngine

// Q&A (v2.5.3)
askQuestion / questionResult / questionFailed
loadQAHistory / qaHistoryLoaded / deleteQAHistory / clearQAHistory
setQnASelectedVideoId / setQnAShowSheet

// Mindmap (v2.5.4/v2.5.5)
generateMindmap / mindmapResult / mindmapFailed / toggleMindmap

// Gemini Key Alert
setGeminiKeyAlert / openSettingsForGeminiKey
```

#### filteredItems computed property
```swift
var filteredItems: [LibraryItem] {
    var result = items
    if filterMode == .recent { /* 7일 필터 */ }
    if let channelId = selectedChannel { result = result.filter { $0.channelId == channelId } }
    if !searchText.isEmpty { result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
    switch sortOrder { case .dateDesc/.dateAsc/.titleAsc/.channelAsc }
    return result
}
```

### 2.7 PlaylistSelectionReducer
모달 시트, fetchPlaylist → toggleAll/toggleItem → confirmSelection.

### 2.8 ChannelReducer
상태: channelURL, channelInfo, videos, isLoading, selectedIDs, preset, filterText, sortOrder, offset 등.

### 2.9 PlayerReducer (v2.6.0)

```swift
@ObservableState
struct State: Equatable {
    var videoURL: URL?
    var title: String = ""
    var channelName: String = ""
    var duration: Int = 0
    var currentTime: Double = 0
    var isPlaying: Bool = false
    var isFullscreen: Bool = false
    var showPanel: Bool = false
    var showSubtitleOverlay: Bool = false
    var subtitles: [SubtitleCue] = []
    var subtitleError: String?
    var isLoadingSubtitles: Bool = false
    var conversionProgress: Double = 0        // v2.6.1
    var conversionETA: String = ""            // v2.6.1
}
```

주요 액션: `openFile(url:title:channelName:duration:)`, `play`, `pause`, `seek(progress:)`, `setCurrentTime`, `togglePlay`, `toggleFullscreen`, `togglePanel`, `toggleSubtitleOverlay`, `subtitlesLoaded`/`subtitleError`/`fetchSubtitles`, `updateConversionProgress`/`updateConversionETA`.

- 자막 로딩 우선순위: DB transcript → 추정 타이밍 (duration 필요) → DB transcript fallback → yt-dlp VTT/SRT
- 자막 언어 우선순위: `.ko.`가 `.en.`보다 먼저 정렬됨 (v2.6.1)
- 변환 진행률: ffmpeg `-progress pipe:1` stdout에서 `out_time_us=` 파싱 → `conversionProgress` + `conversionETA`
- HTML 디코딩: `decodeHTMLEntities()` (static, fileprivate)

---

## 3. UIView / AppKit 통합

### 3.1 메뉴바 (AppDelegate)
```
NSStatusBar.system.statusItem(withLength: 88)
└── NSStatusBarButton
    └── NSView (container, 88×22)
        ├── NSImageView (SF Symbol arrow.down.circle, 14×14)
        ├── NSTextField (statusLabel1, 9px medium)
        └── NSTextField (statusLabel2, 8px regular)
```

### 3.2 윈도우 스펙

| 창 | identifier | 초기 크기 | 최소 크기 | 리사이즈 | zoom |
|----|-----------|----------|----------|---------|------|
| TubeKeep (라이브러리) | `"main"` | 840×640 | 840×500 | 가로 고정 (FixedWidthWindowController) | 가능 |
| 영상 다운로더 | `"downloader"` | 520×480 | 520×300 | 불가 (showsResizeIndicator=false) | 비활성화 |
| 일괄 다운로더 | `"batch"` | 480×420 | 480×340 | 불가 | 비활성화 |
| 채널 다운로더 | `"channel"` | 720×520 | 720×400 | 세로만 (maxHeight 9999) | 비활성화 |
| 설정 | `"settings"` | 560×420 | 560×420 | 고정 (리사이즈 불가) | 비활성화 |
| 플레이어 (v2.6.0) | `"player"` | 854×480 | 854×480 | 불가 | 비활성화 |

#### FixedWidthWindowController
- `NSWindowDelegate.windowWillResize(to:)` 구현 → width를 840으로 고정
- `AppDelegate.mainWindowController` 프로퍼티에 저장하여 dealloc 방지

### 3.3 메뉴바 메뉴 구조
```
튜브킵          → openMainWindow (⌥⌘D)
────────────────
영상 다운로더       → openVideoDownloaderWindow
일괄 다운로더       → openBatchDownloadWindow
채널 다운로더       → openChannelDownloaderWindow
────────────────
설정...           → openSettingsWindow (⌘,)
────────────────
정보              → openAboutWindow
종료               → NSApp.terminate
```

### 3.4 URL 감지 (`isVideoURL`)
- `AppDelegate.swift`와 `HomeView.swift`에 각각 동일한 `isVideoURL(_:)` 함수 존재
- URL host 기반 검사: youtube.com, youtu.be (YouTube 전용)

### 3.5 클립보드 감시
- 2초 간격 Timer → `NSPasteboard.general.string` 확인
- `lastClipboardURL`로 중복 방지
- 라이브러리 창(`"main"`)이 닫혀 있음 → NSPanel 팝오버 표시 (click → 다운로더 창 + autoFetch)
- 라이브러리 창이 열려 있음 → 다운로더 창 오픈 + autoFetch
- 클립보드 알림: NSPanel(.borderless, .nonactivatingPanel), 상태바 아래 위치, 10초 후 auto-dismiss

### 3.6 글로벌 단축키
- `⌥⌘D` → 라이브러리 창
- `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 직접 구현
- AppDelegate의 `HotKey` 클래스

---

## 4. 데이터 모델

### 4.1 LibraryItem
```swift
@Model
final class LibraryItem: Identifiable, @unchecked Sendable {
    @Attribute(.unique) var id: String      // videoId
    var title: String
    var channelId: String
    var channelName: String
    var thumbnailURL: String
    var filePath: String
    var downloadDate: Date
    var uploadDate: Date?
    var duration: Int?                       // 초 단위
    var channelUploadIndex: Int?             // 채널 내 업로드 순서
    var tags: [String]                       // AI 태깅 결과
    var summary: String?                     // AI 요약 (캐시)

    // v2.5.0: AI 콘텐츠 캐싱
    var transcript: String?                  // 자막 텍스트
    var chapters: Data?                      // 챕터 JSON (Data)
    var subtitleLanguage: String?
}
```

### 4.2 LibrarySortOrder
```swift
enum LibrarySortOrder: String, Equatable, CaseIterable {
    case dateDesc = "최신순"
    case dateAsc = "오래된순"
    case titleAsc = "제목순"
    case channelAsc = "채널순"
    case uploadDateDesc = "업로드순 (최신)"
    case uploadDateAsc = "업로드순 (오래된)"
    case indexAsc = "인덱스순"
    case indexDesc = "인덱스 역순"
}
```

### 4.3 LibraryFilterMode
```swift
enum LibraryFilterMode: Equatable {
    case all
    case recent  // 최근 7일
}
```

### 4.4 LibraryViewMode
```swift
enum LibraryViewMode: String, Equatable, CaseIterable {
    case grid = "그리드"
    case list = "목록"
}
```

### 4.5 DownloadItem / VideoInfo / Format / Settings / SubscribedChannel / ChannelVideoItem
(기존과 동일, 생략)

---

## 5. Service 레이어

### 5.1 YouTubeDLService (actor)
- `fetchVideoInfo(url:)` → (VideoInfo, [Format])
- `fetchPlaylist(url:)` → [VideoInfo]
- `download(videoInfo:format:)` → AsyncThrowingStream<ProgressUpdate>
- 내부: Process + yt-dlp, JSON stdout 파싱

### 5.2 DownloadManager (class, singleton, @unchecked Sendable)
- `startDownload(item:)` → Process 시작
- `pauseDownload(id:)` / `resumeDownload(id:)` / `cancelDownload(id:)`
- **동시성 보호**: 2개의 `OSAllocatedUnfairLock` 사용
  - `activeLock`: `[UUID: Process]` 사전 보호 (진행 중인 yt-dlp 프로세스 맵)
  - `stateLock`: `ManagerState` struct 보호 (settings, storageDirectory, filenameTemplate, pausedItems)
    - `startDownload()` 진입 시 Lock에서 값 복사 후 지역 변수 사용 → 내부에서는 Lock 불필요
    - `buildDownloadArgs()` / `constructOutputTemplate()`는 파라미터로 설정값 전달받음
    - `updateSettings()`는 Lock 내부에서 모든 필드 일괄 갱신
- 진행률 파싱: stdout에서 `%(progress._percent_str)s|%(progress._speed_str)s` 추출
- 완료 시 NSSound("Purr") 재생
- **H.264 필터 (v2.6.1)**: `buildDownloadArgs()`에서 모든 포맷에 `[ext=mp4][vcodec^=avc1]` 우선 적용 (YouTubeDLService와 동일)
- **경로 검증 (v2.6.1)**: `--print-to-file after_move:filepath`로 출력 경로 추적 후 `.mp4` 확장자 검증
  - after_move 경로가 `.webp`/`.png` 등 비디오 파일이 아니면, 출력 디렉토리에서 `{videoId}.mp4` 스캔 fallback
  - `--embed-thumbnail`로 생성된 섬네일파일이 after_move를 오염시키는 문제 해결

### 5.3 ProcessRunner (actor)
- `run(arguments:)` → AsyncThrowingStream<String, Error> (실시간 stderr)
- `runSync(arguments:timeout:)` → String (전체 stdout)
- `MutableData` 박스로 Sendable 준수

### 5.4 UploadOrderService (actor)
- `fetchUploadIndex(channelId:videoId:)` → Int?
- 채널 flat-playlist에서 videoId 위치 검색

### 5.5 LibraryCacheService (@MainActor class, singleton)
```swift
@MainActor
final class LibraryCacheService {
    static let shared = LibraryCacheService()
}
```
- **SwiftData 기반 CRUD**: LibraryItem/SubscribedChannel을 SwiftData `@Model`로 관리
  - `loadItems()` → [LibraryItem] (FetchDescriptor)
  - `addItem(LibraryItem)` / `removeItem(id:)`
  - `updateItem(id:tags:)` / `updateItem(id:summary:)`
  - `updateChannelUploadIndices()` — 채널 영상 인덱스 재계산
- **마이그레이션**: v2.4.0에서 UserDefaults → SwiftData 자동 마이그레이션 (`SwiftDataMigration.migrateIfNeeded()`)
- **썸네일 캐시**: NSCache(메모리) + `~/Library/Caches/com.tubekeep/thumbnails/` (디스크)
  - `cachedThumbnail(for:)` / `loadThumbnail(from:videoId:)` / `placeholderThumbnail()`
- **아바타 캐시**: 동일 디렉토리 `avatars/` 하위
  - `cachedAvatar(for:)` / `cacheAvatar(for:data:)` / `placeholderAvatar()`
- **채널명 집계**: `channelNames(from:)` → `[(id, name, count)]`
- **디스크 사용량**: `calculateDiskUsage()` → Int64 (static)
  - FileManager.enumerator로 `storageDirectory` + `~/Library/Caches/com.tubekeep/` 순회, 파일 크기 합산
  - LibraryReducer.diskUsageBytes에 저장

### 5.6 SummarizationService (actor) — v2.0.0/v2.4.0/v2.4.1/v2.5.0
- `summarizeVideo(videoId:title:channel:openRouterAPIKey:ax4APIKey:geminiAPIKey:localFilePath:)` → `SummaryResult`
  - **v2.4.1 폴백 체인**: OpenRouter → yTeaser → A.X 4.0 → Gemini (무료→유료 순서)
  - 1순위: OpenRouter (`summarizeWithOpenRouter`) — 무료 티어, 모델: `openrouter/free`
  - 2순위: yTeaser (`summarizeWithYTeaser`) — 무료 50회/일 (IP 기반)
  - 3순위: A.X 4.0 (`summarizeWithAX4`) — SKT 한국어 특화 LLM, 무료 API
  - 4순위: Gemini (`summarize`) — Google Gemini API, 유료 (API 키 필요)
  - `fetchTranscript(videoId:)` — yt-dlp `--write-subs --write-auto-subs`로 자막 다운로드 → VTT/SRT 파싱
  - `generateSummary(text:title:channel:)` — LLM API 호출 → 개요+핵심포인트+챕터 파싱
  - **v2.5.0**: DB 캐시 확인 후 API 호출, 결과를 DB에 저장
  - **v2.5.1**: 챕터(ChapterInfo) 생성 프롬프트 추가, 챕터 응답 파싱
- `summarizeFromLocalFile(videoPath:title:channel:openRouterAPIKey:geminiAPIKey:)` → `SummaryResult`
  - `extractTranscriptFromLocalFile(videoPath:)` — 같은 디렉토리의 `{videoId}.en.ko.vtt/srt` 검색
  - 외부 자막 파일 없으면 `fetchTranscript(videoId:)`로 YouTube 자막 다운로드 fallback
- 의존성: OpenRouter (`openrouter.ai`), yTeaser (`yteaser.com`), A.X 4.0 (`guest-api.sktax.chat`), Gemini (`generativelanguage.googleapis.com`)
- 에러 처리: `noSubtitle` / `transcriptionFailed` / `summaryFailed` / `quotaExceeded` / `apiUnavailable`

### 5.6.1 AX4Service (v2.4.0)
- A.X 4.0 API 클라이언트 (OpenAI 호환 형식)
- Base URL: `https://guest-api.sktax.chat/v1`
- 모델: `ax4`
- 한국어 특화 LLM (KMMLU 78.3점, CLIcK 83.5점)

### 5.6.2 OpenRouterService (v2.4.1)
- OpenRouter Free Tier API 클라이언트 (OpenAI 호환 형식)
- Base URL: `https://openrouter.ai/api/v1`
- 모델: `openrouter/free`
- 폴백 체인 최상위 우선순위 (무료)

### 5.6.3 DatabaseManager (v2.5.0)
- SQLite3 기반 AI 데이터 저장소 (singleton)
- 테이블: `video_ai_data` (video_id, transcript, summary, chapters, mindmap, podcast_path, tags)
- 테이블: `qna_history` (id, video_id, question, answer, timestamps, created_at)
- CRUD 메서드: saveVideoAIData / loadVideoAIData / updateTranscript / updateSummary / updateChapters / updateMindmap / updatePodcastPath / saveQnAEntry / loadQnAHistory 등

### 5.6.4 QAService (v2.5.3)
- 트랜스크립트 기반 Q&A 생성 서비스 (actor)
- 폴백 체인: OpenRouter → yTeaser → A.X 4.0 → Gemini
- 질문/답변 + 타임스탬프 응답 파싱
- Q&A 히스토리 DB 저장/로드/삭제

### 5.6.5 MindmapService (v2.5.4)
- 마인드맵 생성 서비스 (actor)
- 폴백 체인: OpenRouter → yTeaser → A.X 4.0 → Gemini
- JSON 응답 → MindmapNode 트리 파싱 (재귀적, UUID 자동 생성)
- 생성 결과 DB 저장 + LibraryReducer.mindmapNode에 전달

### 5.7 ChannelFetchService (actor)
- `fetchChannelInfo(url:)` → SubscribedChannel
  - videoCount는 UU playlist의 `playlist_count` 사용 (fallback 실패 시 0)
  - 호출자는 `videoCount: 0`인 경우 기존 값을 보존해야 함
- `fetchAllVideos(channelId:handle:)` → ([ChannelVideoItem], totalCount)
  - URL: `@handle/videos` (숏츠 제외), handle 없으면 UU 플레이리스트 폴백
  - 회원전용 제외: JSON 필드 `availability == "subscriber_only"` 제외
  - 반환: `(videos, videos.count)` — 필터링된 실제 표시 개수
- `fetchAvatarURL(channelId:)` → String?
- yt-dlp flat-playlist + dump-json 사용

### 5.8 PodcastService (actor) — v2.5.2
- `generatePodcastScript(transcript:title:channel:)` → PodcastScript
  - LLM API 활용 (OpenRouter → yTeaser → A.X 4.0 → Gemini)
  - 2인 대화 스크립트 생성 (진행자A/B)
  - 15~25개 세그먼트
- `synthesizeAudio(script:outputDir:)` → String (오디오 파일 경로)
  - AVSpeechSynthesizer 사용 (macOS 내장, 무료)
  - 한국어 음성 (ko-KR)
  - AIFF 형식으로 저장
- `generatePodcast(videoId:title:channel:transcript:)` → PodcastResult
  - 전체 파이프라인: 스크립트 생성 → TTS 변환 → 파일 저장
- `deletePodcast(videoId:)` → Bool
  - 팟캐스트 디렉토리 + DB 레코드 삭제
- 저장 위치: `~/Documents/TubeKeep/Podcasts/{videoId}/`
- 의존성: SummarizationService (LLM API), AVFoundation (TTS)

---

## 6. UI 레이아웃

### 6.1 라이브러리 뷰 (LibraryView)

```
● ● ●  라이브러리            [영상다운] [일괄다운] [채널다운]  📌 ✕

├──────────────┬───────────────────────────────────────────────────┤
│ 🔍 검색...   │  N개 항목                         정렬 [최신순] [≡]│
│──────────────│───────────────────────────────────────────────────│
│ 전체 (42)    │  ┌──────────┐  ┌──────────┐                    │
│ 최근 (7)     │  │ 16:9     │  │ 16:9     │                    │
│──────────────│  │ 썸네일   │  │ 썸네일   │                    │
│ 🟦 채널A (15)│  │          │  │          │                    │
│ 🟩 채널B (8) │  │ 제목     │  │ 제목     │                    │
│ 🟪 채널C (21)│  │ 채널명   │  │ 채널명   │                    │
│ ...          │  │ 날짜     │  │ 날짜     │                    │
│              │  └──────────┘  └──────────┘                    │
│              │  ┌──────────┐  ┌─────────────────────┐        │
│              │  │ 16:9     │  │  🎬                 │        │
│              │  │ 썸네일   │  │  영상은 아래와      │        │
│              │  │          │  │  같은 방법으로      │        │
│              │  │ 제목     │  │  다운로드 받으실    │        │
│              │  │ 채널명   │  │  수 있습니다        │        │
│              │  │ 날짜     │  │                     │        │
│              │  └──────────┘  │ [영상다운] [일괄다운]│        │
│              │               │    [채널다운]       │        │
│              │               └─────────────────────┘        │
└──────────────┴───────────────────────────────────────────────────┘
```

#### 좌측 사이드바 (200px 고정)
- 검색창 (돋보기 SF Symbol + TextField)
- `전체 (N)` / `최근 (N)` filterRow
- Divider
- `채널` section header
- 채널 목록: 아바타(20×20 원형, disk+NSCache) + 채널명 + 개수
  - 우클릭 contextMenu: 채널로 가기 / 채널 다운로더 열기
  - 클릭 → filterMode=all + selectedChannel=channelId
  - drag-to-reorder (onMove → UserDefaults `channelOrder` 저장) [T-117]
- Divider
- `+ 채널 추가` 버튼 → `openChannelWindowNotification` [T-118]
- Divider
- `저장 폴더 열기` 버튼 → NSWorkspace.open [T-110] (현재 "Finder에서 보기")
- 디스크 사용량: `Finder에서 보기  12.3 GB  ↻` — ByteCountFormatter, ↻ 버튼으로 수동 갱신 [T-126/T-127]
  - 갱신 시점: onAppear, downloadCompleted, removeSelected, removeItemsByChannel

#### 우측 영역 (flex)
- **sortBar**: `N개 항목` | Spacer | 정렬 Picker | viewModeToggle
- **selectionBar** (선택 시만 표시): `N개 선택됨` | 전체 선택 | 선택 해제 | 선택 삭제 [T-112]
- **그리드 모드**: LazyVGrid adaptive(min:180, max:300), spacing 16, padding 16
  - LibraryGridCell: 16:9 썸네일 + 제목(2줄 12pt) + 채널명(11pt) + 날짜(10pt)
  - hover 시 `.popover`로 360×203 확대 썸네일, bottom-right가 셀 중앙에 정렬 (기존 썸네일 우상단 1/4 가림) [T-111]
  - 좌클릭 → LeftClickMenu: 열기 / 자막 다운로드 / Finder에서 보기 / 삭제
  - Cmd+클릭 → selection toggle [T-112]
  - EmptyLibraryCell: 그리드 아래 full-width, 안내문 + 3개 버튼
- **목록 모드**: LazyVStack + Divider
  - LibraryListRow: 48×27 썸네일 + 제목 + 채널명 + 날짜
  - 동일한 LeftClickMenu + Cmd+클릭 선택

### 6.2 LeftClickMenu (NSViewRepresentable)
- `NSClickGestureRecognizer`로 좌클릭 감지
- Cmd+클릭 시 `onToggleSelection` 호출 (메뉴 미표시) [T-112]
- `NSEvent.mouseLocation` 기준 `NSMenu.popUp(positioning:at:in:)`
- 항목: `LeftClickMenuEntry` enum (action / separator)
- destructive 항목은 빨간색 attributedTitle
- 자막 다운로드 옵션 추가 [T-116]

### 6.3 영상 다운로더 뷰 (VideoDownloadView)
```
VStack(spacing: 0)
├── HomeView(padding: 16, pin+close toolbar)
├── Divider
├── DownloadQueueView(.frame(maxHeight: .infinity))
```

### 6.7 설정 뷰 (SettingsView) — 네이티브 설정 창 (⌘,)
- `AppDelegate.openSettingsWindow()` → NSWindow 직접 생성/관리 (`TubeKeepApp`은 빈 Scene)
- 메뉴바 "설정..." (⌘,) + `NSEvent.addLocalMonitorForEvents` 글로벌 모니터로 모든 창에서 접근 가능
- **v2.2.0**: 4탭 레이아웃 (일반/저장/시스템/AI 요약) → **v2.7.2**: 5탭 (다운로드/저장/알림 신규/시스템/AI 설정) — 좌측 140pt 사이드바 + 우측 ScrollView
- `SettingsRow<Control>` 제네릭 컴포넌트: Title + Description 수직 스택 + Control
- `SummaryServiceMode` 제거 (v2.2.0) — 항상 OpenRouter → yTeaser → A.X 4.0 → Gemini 자동 폴백
- 창 크기: 가로 560px 고정, 세로 420px 고정 (리사이즈 불가)

### 6.4 DownloadQueueView
- footer: 다운로드 요약
- DownloadRow: WaveProgress(파란색 채움) + hover 삭제버튼
- 우클릭 메뉴
- 토스트 배너

### 6.5 BatchDownloadView
- idle: TextEditor(다중 URL) + preset + 실행버튼
- processing: URL 리스트 + ProgressView
- completed: 리스트 유지 + 5초 카운트다운 → window close

### 6.6 ChannelDownloaderView
- HSplitView: ChannelListView(220px) + ChannelContentView
- ChannelListView: drag-drop 재정렬, 우클릭 삭제
- ChannelContentView: 채널헤더 + 검색/정렬 + 프리셋 + 다운로드버튼

---

## 7. ViewModifier / Extension

### AlwaysOnTopModifier
```swift
func alwaysOnTop(_ isOnTop: Bool, windowIdentifier: String = "main") -> some View
```
- `NSViewRepresentable` → `window.level = .floating / .normal`

### leftClickMenu
```swift
extension View {
    func leftClickMenu(entries: [LeftClickMenuEntry]) -> some View
}
```
- 좌클릭 시 네이티브 NSMenu 표시

---

## 8. DebugLogView (DEBUG 전용)

### 목적
- 모든 서비스/Reducer의 동작을 단일 로그 창에서 실시간 확인
- 창 생성/포커스/닫힘/버튼 클릭 등 주요 이벤트 기록
- **DEBUG 빌드에서만 컴파일** (#if DEBUG)

### DebugLogManager (class, ObservableObject — Singleton)
```swift
#if DEBUG
final class DebugLogManager: ObservableObject {
    nonisolated(unsafe) static var shared: DebugLogManager?

    @Published var logs: [String] = []
    
    func append(_ message: String) {
        let timestamp = DateFormatter()
        timestamp.dateFormat = "HH:mm:ss.SSS"
        logs.append("[\(timestamp.string(from: Date()))] \(message)")
    }
    
    func clear() { logs.removeAll() }
}
#endif
```
- **단일 싱글톤** (`DebugLogManager.shared`) — AppDelegate의 `applicationDidFinishLaunching`에서 1회 생성
- 모든 서비스/Reducer(View 포함)가 `DebugLogManager.shared?.append()`로 접근
- `DebugLogManager` 자체가 `#if DEBUG`로 감싸져 있어 릴리즈 빌드에서 개별 호출에 `#if DEBUG` 불필요

### DebugLogView (SwiftUI View) + DebugLogWindowView (독립 창)
- `DebugLogView`: 공유 뷰 컴포넌트 — `@ObservedObject var manager: DebugLogManager`를 받아 로그 목록 표시
- `DebugLogWindowView`: 독립 NSWindow로 표시 — 메뉴바 "디버그 로그 열기 (Cmd+D)"로 열림
- 기능: 라인 선택 (Cmd/Shift 다중 선택), 자동 스크롤, 전체/선택 복사, 클리어, 최상위 고정(pin)

### 통합 방식
- 더 이상 각 window의 root view 하단에 `DebugLogView`를 직접 추가하지 않음
- `DebugLogWindowView`가 독립 창에서 모든 로그를 통합 표시
- ChannelDownloaderView 등은 자체 debugLogs 배열 대신 `DebugLogManager.shared?.append()`를 직접 호출
- `#if DEBUG` 가드 불필요 (DebugLogManager 자체가 DEBUG 전용)

### 로그 프리픽스 규칙
각 서비스/Reducer는 식별 가능한 프리픽스를 붙인다:
- `[Channel]` — ChannelDownloaderView
- `[Download]` — DownloadQueueReducer
- `[Player]` — PlayerReducer
- `[Library]` — LibraryReducer
- `[History]` — LibrarySidebarView / HistoryView
- `[Podcast]` — PodcastService
- `[App]` — AppDelegate
- `[YouTubeDL]` — YouTubeDLService
- `[Whisper]` — WhisperService
- `[Subtitle]` — SummarizationService
- 등

### 파일 위치
```
Sources/TubeKeep/Debug/
├── DebugLogManager.swift
└── DebugLogView.swift
```

---

## 9. Constants

```swift
enum Constants {
    static let appName = "TubeKeep"
    static let defaultResolution = 360
    static let defaultConcurrentDownloads = 2
    static let min/maxConcurrentDownloads = 1/5
    static let defaultMaxRetries = 3
    static let defaultOutputDirectory = "~/Downloads"
    static let defaultFilenameTemplate = "{channel} - {index} - {title}"
    static let statusBarWidth: CGFloat = 88
    static let statusBarHeight: CGFloat = 22
    static let queueSaveKey = "savedDownloadQueue"        // 미사용
    static let settingsSaveKey = "appSettings"
    static let librarySaveKey = "downloadLibrary"
    static let libraryViewModeKey = "libraryViewMode"
    static let channelOrderKey = "channelOrder"       // T-117
    static let downloadQueueKey = "downloadQueue"     // T-115
    static let appGroupSuiteName = "com.tubekeep.shared"

    // Cache (v2.6.1)
    static var transcodedCacheDirectory: URL    // ~/Library/Caches/com.tubekeep/transcoded/

    // Notification Center (내부)
    static let openMainWindowNotification = Notification.Name("com.tubekeep.openMainWindow")
    static let openDownloaderWindowNotification = Notification.Name("com.tubekeep.openDownloaderWindow")
    static let openBatchWindowNotification = Notification.Name("com.tubekeep.openBatchWindow")
    static let openChannelWindowNotification = Notification.Name("com.tubekeep.openChannelWindow")
    static let openPlayerWindowNotification = Notification.Name("com.tubekeep.openPlayerWindow")    // v2.6.0

    // yt-dlp / ffmpeg
    static var ytDlpPath: String { get }  // 번들 → brew → PATH
    static var ffmpegPath: String { get } // 번들 → brew → PATH
    static var ffprobePath: String { get } // 번들 → brew → PATH (v2.6.1 ffmpeg 병합용, v2.7.2 코덱 검사는 AVAsset.loadTracks로 대체)
    static var youtubeExtractorArgs: String { get } // "youtube:lang=XX" (시스템 언어 기반)

    // URL utils
    static func isChannelURL(_ url: String) -> Bool
    static func channelIDFromURL(_ url: String) -> String?
    static func sanitizeFolderName(_ name: String) -> String
}
```

---

## 10. 파일 목록 (84 Swift 파일)

### App/ (9)
| 파일 | 설명 |
|------|------|
| `TubeKeepApp.swift` | `@main` entry point, 빈 SwiftUI Scene |
| `AppDelegate.swift` | 메뉴바, 4개 윈도우, 단축키, 클립보드, URL scheme |
| `AppReducer.swift` | Root TCA reducer, 브릿지 로직 |
| `VideoDownloadView.swift` | 영상 다운로더 메인 뷰 (Home+Queue) |
| `StatusBarView.swift` | StatusBarReducer (메뉴바 상태) |
| `StatusBarManager.swift` | 메뉴바 상태 관리 + 메뉴 구성 (v2.4.0 AppDelegate 분리); v2.7.2: queue item action:nil→#selector 수정 |
| `ClipboardMonitor.swift` | 클립보드 감시 + NSPanel 알림 (v2.4.0 AppDelegate 분리) |
| `ChannelUpdateService.swift` | 채널 업데이트 30분 타이머 폴링 (v2.4.0 AppDelegate 분리) |
| `FixedWidthWindowController.swift` | 라이브러리 창 가로 840px 고정 |

### Features/ (28)
| 파일 | 설명 |
|------|------|
| `AboutView.swift` | 정보 창 |
| `Home/HomeReducer.swift` | URL 입력 + 정보 조회 reducer |
| `Home/HomeView.swift` | URL 입력 + 정보 카드 + 포맷 선택 UI |
| `BatchDownload/BatchDownloadView.swift` | 일괄 다운로더 UI |
| `PlaylistSelection/PlaylistSelectionReducer.swift` | 플레이리스트 선택 reducer |
| `PlaylistSelection/PlaylistSelectionView.swift` | 플레이리스트 시트 UI |
| `Channel/ChannelContentView.swift` | 채널 콘텐츠 (헤더+비디오목록+다운로드) |
| `Channel/ChannelDownloaderView.swift` | 채널 다운로더 창 root |
| `Channel/ChannelListView.swift` | 채널 목록 사이드바 |
| `Settings/SettingsReducer.swift` | 설정 reducer (v2.2.0: 4탭; v2.7.2: 5탭) |
| `Settings/SettingsView.swift` | 설정 UI (SettingsRow 제네릭 컴포넌트) |
| `Library/LibraryReducer.swift` | 라이브러리 reducer (v2.5.x: podcast/Q&A/mindmap) |
| `ToastComponents.swift` | ToastMessage/ToastBanner/ToastOverlay 공유 컴포넌트 (v2.7.0) |
| `Library/MainView.swift` | 라이브러리 root (sidebar + toolbar + AIWindowView) |
| `Library/LibrarySidebarView.swift` | 사이드바 (검색/필터/채널목록/디스크사용량) |
| `Library/LibraryGridView.swift` | 그리드 모드 + LeftClickMenu + 빈 상태 |
| `Library/LibraryListView.swift` | 목록 모드 |
| `Library/QAView.swift` | Q&A UI (v2.5.3) |
| `Library/MindmapView.swift` | 마인드맵 트리 UI (v2.5.4) |
| `DownloadQueue/DownloadQueueReducer.swift` | 다운로드 큐 reducer |
| `DownloadQueue/DownloadQueueView.swift` | 다운로드 큐 UI |
| `Discover/DiscoverView.swift` | 트렌딩/검색 카드 그리드 (v2.0.0) |
| `Player/PlayerReducer.swift` | 플레이어 TCA reducer (자막 로딩/파싱, 변환 진행률) (v2.6.0) |
| `Player/PlayerView.swift` | 플레이어 본문 (트랜스코딩 캐시, 호버 컨트롤, 변환 진행바) (v2.6.0) |
| `Player/NSPlayerView.swift` | AVPlayerView NSViewRepresentable (autoresizingMask) (v2.6.0) |
| `Player/PlayerItem.swift` | 플레이어 재생 항목 모델 (v2.6.0) |
| `Player/SubtitleOverlay.swift` | 비디오 위 자막 오버레이 (v2.6.0) |
| `Player/SubtitlePanel.swift` | 자막 패널 (로딩/에러/빈 상태) (v2.6.0) |

### Services/ (22)
| 파일 | 설명 |
|------|------|
| `YouTubeDLService.swift` | yt-dlp 정보 조회 actor |
| `DownloadManager.swift` | 다운로드 프로세스 관리 (OSAllocatedUnfairLock) |
| `ProcessRunner.swift` | async Process 실행 |
| `LibraryCacheService.swift` | 라이브러리 CRUD + 썸네일/아바타 캐시 (@MainActor singleton, SwiftData) |
| `ChannelFetchService.swift` | 채널 정보 fetch actor |
| `UploadOrderService.swift` | 업로드 순번 조회 actor |
| `TrendingService.swift` | yt-dlp `ytsearch` 기반 트렌딩 검색 + 30분 TTL 캐시 |
| `SummarizationService.swift` | OpenRouter → yTeaser → A.X 4.0 → Gemini 4단계 요약 |
| `TaggingService.swift` | OpenRouter → A.X 4.0 → Gemini → 규칙 기반 자동 태깅 |
| `AX4Service.swift` | SKT A.X 4.0 API 클라이언트 (OpenAI 호환) |
| `OpenRouterService.swift` | OpenRouter Free Tier API 클라이언트 (v2.4.1) |
| `PodcastService.swift` | AI 팟캐스트 생성 (LLM + TTS) |
| `TTSService.swift` | AVSpeechSynthesizer 래퍼 (한국어 TTS) |
| `QAService.swift` | Q&A 생성 서비스 (v2.5.3) |
| `MindmapService.swift` | 마인드맵 생성/파싱/DB 저장 서비스 (v2.5.4) |
| `WhisperService.swift` | Whisper CoreML 음성인식 자막 생성 (v2.7.0) |
| `LanguageService.swift` | 시스템 언어 기반 동적 전환 유틸리티 (v2.7.0) |
| `DatabaseManager.swift` | SQLite DB 관리 (video_ai_data + qna_history + download_history) |
| `PersistenceController.swift` | SwiftData ModelContainer 관리 (v2.4.0) |
| `SwiftDataMigration.swift` | UserDefaults → SwiftData 자동 마이그레이션 (v2.4.0) |
| `EdgeTTSClient.swift` | Edge TTS API 클라이언트 (실험적) |
| `ErrorMessageMapper.swift` | yt-dlp 에러 메시지 한글 매핑 (v2.3.0) |

### Models/ (14)
| 파일 | 설명 |
|------|------|
| `LibraryItem.swift` | `@Model class` — SwiftData 영구 저장 (sortOrder/filterMode/viewMode enum 포함) |
| `VideoInfo.swift` | YouTube 영상 메타데이터 |
| `DownloadItem.swift` | 다운로드 작업 모델 |
| `Format.swift` | 비디오 포맷 |
| `Settings.swift` | 설정 모델 (SettingsTab enum 포함) — v2.7.0: subtitleLanguageOverride, cookiesFromBrowser, enableAISubtitles, whisperModelDownloaded, presets, smartMode, activePresetId |
| `DownloadPreset.swift` | 다운로드 프리셋 모델 (v2.7.0) |
| `SubscribedChannel.swift` | `@Model class` — 구독 채널 SwiftData 모델 |
| `ChannelModels.swift` | 채널 비디오 + 캐시 |
| `BatchPreset.swift` | 일괄 다운로드 프리셋 |
| `TrendingVideo.swift` | 트렌딩 영상 + TrendingCategory 열거형 (systemIcon) |
| `PodcastModels.swift` | PodcastScript, PodcastSegment, PodcastResult |
| `QAModels.swift` | QAResponse, QATimestamp, QAHistoryItem |
| `MindmapModels.swift` | MindmapNode (재귀적 Codable, Custom CodingKeys) |

### Helpers/ (5)
| 파일 | 설명 |
|------|------|
| `Constants.swift` | 앱 상수 + 유틸리티 (keyCode 기반 단축키) |
| `LanguageService.swift` | 시스템 언어 기반 동적 전환 (v2.7.0) |
| `WindowAccessor.swift` | alwaysOnTop NSViewRepresentable modifier |
| `BookmarkManager.swift` | Security-scoped bookmark 관리 (저장 폴더 접근 권한) |
| `ImageCacheEnvironmentKey.swift` | EnvironmentKey 기반 캐시 주입 |

### Debug/ (2) — DEBUG 전용
| 파일 | 설명 |
|------|------|
| `DebugLogManager.swift` | `ObservableObject` 로그 관리자 (타임스탬프 자동 추가) |
| `DebugLogView.swift` | SwiftUI 로그 뷰 (자동 스크롤, 복사 가능) |

### Features/Library/ (v2.7.0 추가)
| 파일 | 설명 |
|------|------|
| `HistoryView.swift` | 다운로드 히스토리 테이블 뷰 + 검색 + 필터 |

### Views/ (1)
| 파일 | 설명 |
|------|------|
| `CachedImageViews.swift` | CachedThumbnailView + CachedAvatarView 공유 컴포넌트 |

### Build/ (1)
| 파일 | 설명 |
|------|------|
| `build_and_run.sh` | 빌드 스크립트 — debug/release + yt-dlp/ffmpeg 번들링 + 설치 + 실행 |

---

## 11. 데이터 저장 키 총정리

### SwiftData (v2.4.0+)
| @Model | 테이블 | 주요 속성 |
|--------|--------|-----------|
| `LibraryItem` | SwiftData 자동 | `id, title, channelId, filePath, downloadDate, tags, summary, transcript, chapters, ...` |
| `SubscribedChannel` | SwiftData 자동 | `id, name, avatarURL, videoCount, ...` |

### UserDefaults
| 키 | 타입 | 내용 |
|----|------|------|
| `"appSettings"` | JSON | Settings (concurrentDownloads, storageDirectory, OpenAI API 키, ...) |
| `"libraryViewMode"` | String | `"grid"` or `"list"` |
| `"channelOrder"` | JSON | `[String]` 채널 ID 정렬 순서 (T-117) |
| `"channelDownloads"` | [String] | 다운로드 완료된 videoId 목록 |
| `"channelFetchTimestamps"` | [String: Date] | 채널별 마지막 fetch 시간 |
| `"channelVideosData"` | JSON | 채널별 비디오 목록 캐시 |
| `"channelsNewVideos"` | JSON | `[channelId: [videoId]]` 채널별 미확인 새 영상 ID 목록 (T-114) |
| `"channelsSeenVideoIds"` | JSON | `[channelId: [videoId]]` 채널별 확인 완료 영상 ID 목록 (T-114) |
| `"downloadQueue"` | JSON | `[DownloadItem]` 큐 영속성 (T-115) |

### SQLite (v2.5.0+) — `~/Library/Application Support/com.borasarang.tubekeep/tubekeep_ai.db`
| 테이블 | 컬럼 | 설명 |
|--------|------|------|
| `video_ai_data` | `video_id (PK), transcript, transcript_language, summary, chapters (JSON), mindmap (JSON), podcast_path, tags (JSON), created_at, updated_at` | AI 콘텐츠 캐시 |
| `qna_history` | `id (PK), video_id (FK), question, answer, timestamps (JSON), created_at` | Q&A 히스토리 |
| `download_history` (v2.7.0) | `id (PK), video_id, title, channel_name, url, format_label, resolution, file_size, file_path, downloaded_at, status` | 다운로드 완료 내역 |

---

## 12. v2.7.0 — 시스템 언어 + 쿠키 인증 + Whisper AI 자막 + 프리셋 + 히스토리

### 12.1 LanguageService (시스템 언어 동적 전환)

**파일**: `Helpers/LanguageService.swift` (신규)

```swift
enum LanguageService {
    /// 시스템 언어 코드 (예: "ko", "en", "ja")
    static var systemLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// 자막 다운로드 언어 리스트 (시스템 언어 우선, 영어 fallback)
    /// 예: ko→"ko,en", en→"en", ja→"ja,en"
    static var subtitleLanguages: String {
        let primary = systemLanguageCode
        let secondary = primary == "en" ? "" : "en"
        return secondary.isEmpty ? primary : "\(primary),\(secondary)"
    }
    
    /// Edge TTS 음성 맵핑
    static func ttsVoice(for engine: TTSEngine) -> (male: String, female: String) {
        if engine == .apple {
            return (appleVoice(.male), appleVoice(.female))
        }
        let map: [String: (male: String, female: String)] = [
            "ko": ("ko-KR-InJoonNeural", "ko-KR-SunHiNeural"),
            "en": ("en-US-ChristopherNeural", "en-US-JennyNeural"),
            "ja": ("ja-JP-KeitaNeural", "ja-JP-NanamiNeural"),
            "zh": ("zh-CN-YunxiNeural", "zh-CN-XiaoxiaoNeural"),
            "es": ("es-ES-AlvaroNeural", "es-ES-ElviraNeural"),
            "fr": ("fr-FR-HenriNeural", "fr-FR-DeniseNeural"),
            "de": ("de-DE-ConradNeural", "de-DE-KatjaNeural"),
        ]
        return map[systemLanguageCode] ?? ("ko-KR-InJoonNeural", "ko-KR-SunHiNeural")
    }
    
    static func appleVoice(_ gender: TTSEngine.Gender) -> String {
        let map: [String: String] = [
            "ko": "ko-KR.Yuna", "en": "en-US.Samantha", "ja": "ja-JP.Kyoko",
        ]
        return map[systemLanguageCode] ?? "ko-KR.Yuna"
    }
    
    /// AI 프롬프트에 주입할 언어 지시문
    static var aiPromptLanguage: String {
        switch systemLanguageCode {
        case "ko": return "한국어로 응답해주세요."
        case "ja": return "日本語で答えてください。"
        default:   return "Answer in English."
        }
    }
}
```

**Settings 연동** (선택적 override):
```swift
var subtitleLanguageOverride: String = ""  // 빈 값 = 시스템 언어 따름
// 사용 시 LanguageService.subtitleLanguages 대신 이 값을 --sub-langs에 사용
```

**변경 포인트 (12개 파일)**:
| 파일 | 현재 | 변경 |
|------|------|------|
| `DownloadManager.swift:252` | `"en,ko"` | `settings.subtitleLanguages` |
| `YouTubeDLService.swift` 2곳 | `"en,ko"` | `LanguageService.subtitleLanguages` |
| `PlayerReducer.swift:238` | `"ko,en"` | `LanguageService.subtitleLanguages` |
| `SummarizationService.swift:240` | `"en,ko"` | `LanguageService.subtitleLanguages` |
| `LibraryReducer.swift:419` | `"en,ko"` | `LanguageService.subtitleLanguages` |
| `TTSService.swift:24,92` | `"ko-KR"` | `LanguageService.appleTTSLanguage` |
| `EdgeTTSClient.swift:47,105` | `"ko-KR-InJoonNeural"` | `LanguageService.ttsVoice(for:)` |
| `PodcastService.swift:19-20` | 하드코딩 | `LanguageService.ttsVoice(for:)` |

---

### 12.2 브라우저 쿠키 인증

**설계**: 모든 yt-dlp `Process` 호출에 `--cookies-from-browser {browser}` 플래그 조건부 추가

**Settings 추가 필드**:
```swift
var cookiesFromBrowser: String = ""  // 빈 값 = 미사용, 값 = safari/chrome/brave/edge/firefox
```

**SettingsView** (시스템 탭):
```swift
SettingsRow(title: "브라우저 쿠키 사용", description: "비공개/연령 제한 영상 접근") {
    Picker("", selection: ...) {
        Text("사용 안 함").tag("")
        Text("Safari").tag("safari")
        Text("Chrome").tag("chrome")
        Text("Brave").tag("brave")
        Text("Edge").tag("edge")
        Text("Firefox").tag("firefox")
    }
}
```

**플래그 적용**:
```swift
// YouTubeDLService + DownloadManager 공통
if !settings.cookiesFromBrowser.isEmpty {
    args += ["--cookies-from-browser", settings.cookiesFromBrowser]
}
```

**적용되는 yt-dlp 호출**:
| 호출 | 함수 | 파일 |
|------|------|------|
| 정보 조회 | `fetchVideoInfo()` | YouTubeDLService |
| 스트리밍 URL | `fetchStreamingURL()` | YouTubeDLService |
| 자막 다운로드 | `fetchSubtitles()` | YouTubeDLService |
| 영상 다운로드 | `runDownload()` | DownloadManager |
| 자막 fetch | `fetchTranscript()` | SummarizationService |
| Player 자막 | `loadSubtitles()` | PlayerReducer |
| Library 자막 | `downloadSubtitles()` | LibraryReducer |

---

### 12.3 AI 자막 생성 (Whisper CoreML)

#### 아키텍처

```
yt-dlp 자막 실패
       │
       ▼
  ┌────────────────────────────┐
  │  WhisperService (actor)    │
  │  ┌──────────────────────┐  │
  │  │ downloadAudio()      │  │  yt-dlp -x --audio-format wav
  │  │                      │  │
  │  │ transcribe(wav, lang)│  │  WhisperKit pipeline
  │  │                      │  │
  │  │ → [SubtitleCue]      │  │
  │  └──────────────────────┘  │
  └────────────────────────────┘
       │
       ▼
  DatabaseManager.updateTranscript(videoId, transcript, language)
```

#### WhisperService (actor)

```swift
actor WhisperService {
    static let shared = WhisperService()
    private var pipeline: WhisperKit?
    
    @MainActor @Published var downloadProgress = DownloadProgress(
        fraction: 0, speed: "", eta: "", state: .idle
    )
    
    struct DownloadProgress {
        enum State { case idle, downloading, completed, failed(String) }
        var fraction: Double, speed: String, eta: String, state: State
    }
    
    var isModelReady: Bool {
        UserDefaults.standard.bool(forKey: "whisper_model_downloaded")
    }
    
    func downloadModel() async throws {
        // Hugging Face → ~/Library/Caches/com.tubekeep/whisper/models/
        // URLSessionDownloadDelegate로 progress 업데이트
        // 완료 → UserDefaults 저장
    }
    
    func transcribe(audioURL: URL, language: String?) async throws -> [SubtitleCue] {
        if pipeline == nil {
            pipeline = try await WhisperKit.loadModel()
        }
        let result = try await pipeline!.transcribe(audioPath: audioURL.path, language: language)
        return result.segments.map { SubtitleCue(startTime: $0.start, endTime: $0.end, text: $0.text) }
    }
}
```

#### 모델 다운로드 UX

```
Settings AI 탭:
┌──────────────────────────────────────────────┐
│  AI 자막 생성 (Whisper)                      │
│  ─────────────────                           │
│  영상의 음성을 인식하여 자동으로 자막을       │
│  생성합니다. 자막이 없는 영상도 한국어/영어   │
│  등 원하는 언어의 자막을 생성할 수 있습니다.  │
│                                              │
│  [■ AI 자막 생성 사용] ← 토글                │
│                                              │
│  (모델 미설치 시)                             │
│  ⚠️ Whisper 음성 인식 모델(~500MB)을        │
│  다운로드해야 합니다.                        │
│  [모델 다운로드] [나중에]                    │
│                                              │
│  (다운로드 중)                                │
│  ████████████░░░░ 220/500 MB                │
│  ⬇ 3.2 MB/s  •  남은 시간: 1분 30초       │
│  [취소]                                      │
│                                              │
│  (완료)                                      │
│  ✅ Whisper 모델 다운로드 완료              │
│  [모델 삭제]                                 │
└──────────────────────────────────────────────┘

앱 전체 토스트 (설정 외 화면에서도 표시):
┌──────────────────────────────────────┐
│ ⬇ Whisper 모델 다운로드 중... 45%   │
└──────────────────────────────────────┘
완료: "✅ Whisper 모델 다운로드 완료" (3초 후 사라짐)
실패: "❌ 다운로드 실패 — [재시도]" (유지)
```

#### 플레이어 통합 (PlayerReducer)

```swift
// loadSubtitles 3차 fallback
case .subtitlesFailed:
    if state.settings.enableAISubtitles, WhisperService.shared.isModelReady {
        let audioURL = try await downloadAudio(videoId: videoId, url: url)
        let cues = try await WhisperService.shared.transcribe(audioURL: audioURL, language: LanguageService.systemLanguageCode)
        let text = cues.map(\.text).joined(separator: " ")
        DatabaseManager.shared.updateTranscript(videoId: videoId, transcript: text, language: LanguageService.systemLanguageCode)
        await send(.subtitlesLoaded(cues))
    }
```

#### 요약 서비스 통합 (SummarizationService)

```swift
// fetchTranscript 3차 fallback
if settings.enableAISubtitles, WhisperService.shared.isModelReady {
    let audioURL = try await downloadAudio(videoId: videoId, url: "https://youtu.be/\(videoId)")
    let cues = try await WhisperService.shared.transcribe(audioURL: audioURL, language: LanguageService.systemLanguageCode)
    // 저장 + 반환
}
```

#### 오디오 다운로드 헬퍼

```swift
private let whisperCacheDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("com.tubekeep.whisper", isDirectory: true)

func downloadAudio(videoId: String, url: String) async throws -> URL {
    try FileManager.default.createDirectory(at: whisperCacheDir, withIntermediateDirectories: true)
    let output = whisperCacheDir.appendingPathComponent("\(videoId).wav")
    let args = [Constants.ytDlpPath, "-x", "--audio-format", "wav",
                "--no-warnings", "-o", output.path, url]
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    try process.run()
    process.waitUntilExit()
    return output
}
```

---

### 12.4 다운로드 프리셋 / Smart Mode

#### DownloadPreset 모델

```swift
struct DownloadPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String                       // "4K 영상", "오디오만" 등
    var formatType: PresetFormatType       // .video / .audio
    var resolution: Int                    // 2160/1080/720/480/360
    var includeSubtitles: Bool
    var sponsorBlock: Bool
    var embedMetadata: Bool
    var storageDirectory: String?          // nil = Settings 기본값
    
    enum PresetFormatType: String, Codable {
        case video = "영상"
        case audio = "오디오"
    }
}
```

#### Settings 추가 필드

```swift
var presets: [DownloadPreset] = [
    DownloadPreset(id: UUID(), name: "고품질 (4K)", formatType: .video,
                   resolution: 2160, includeSubtitles: true,
                   sponsorBlock: true, embedMetadata: true),
    DownloadPreset(id: UUID(), name: "기본 (1080p)", formatType: .video,
                   resolution: 1080, includeSubtitles: true,
                   sponsorBlock: true, embedMetadata: true),
    DownloadPreset(id: UUID(), name: "오디오만", formatType: .audio,
                   resolution: 0, includeSubtitles: false,
                   sponsorBlock: false, embedMetadata: false),
]
var activePresetId: UUID?  // nil = 수동 선택 (Smart Mode OFF여도 사용)
var smartMode: Bool = false
```

#### 다운로드 플로우 (VideoDownloadView 수정)

```
Smart Mode OFF (현행 유지):
  URL 입력 → 정보 조회 → 포맷 선택 → 다운로드 시작

Smart Mode ON:
  URL 입력 → 정보 조회 → 활성 프리셋 자동 적용 → 큐에 바로 추가
```

**프리셋 적용 로직**:
```swift
func applyPreset(_ preset: DownloadPreset, to item: inout DownloadItem, formats: [Format]) {
    if preset.formatType == .audio {
        item.audioOnly = true
        item.selectedFormat = formats.first(where: { $0.isAudioOnly }) ?? formats.first!
    } else {
        item.audioOnly = false
        item.selectedFormat = formats
            .filter { !$0.isAudioOnly && $0.height <= preset.resolution }
            .sorted { $0.height > $1.height }
            .first ?? formats.first { !$0.isAudioOnly }!
    }
    item.includeSubtitles = preset.includeSubtitles
}
```

---

### 12.5 다운로드 히스토리 (DB)

#### DB 테이블

```sql
CREATE TABLE IF NOT EXISTS download_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id TEXT,
    title TEXT NOT NULL,
    channel_name TEXT,
    url TEXT NOT NULL,
    format_label TEXT,
    resolution INTEGER,
    file_size INTEGER,
    file_path TEXT,
    downloaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'completed'
);
```

#### DownloadHistoryItem 모델

```swift
struct DownloadHistoryItem: Identifiable, Equatable {
    let id: Int64
    let videoId: String?
    let title: String
    let channelName: String?
    let url: String
    let formatLabel: String?
    let resolution: Int?
    let fileSize: Int64?
    let filePath: String?
    let downloadedAt: Date
    let status: DownloadStatus
    
    enum DownloadStatus: String { case completed, failed, cancelled }
}
```

#### 저장 시점

```swift
// AppReducer.downloadCompleted (line 326 부근)
case let .downloadCompleted(item, success, outputPath, ...):
    DatabaseManager.shared.saveDownloadHistory(
        DownloadHistoryItem(
            videoId: item.videoInfo.videoId,
            title: item.videoInfo.title,
            channelName: item.videoInfo.channelName,
            url: item.videoInfo.webpageURL,
            formatLabel: item.selectedFormat.label,
            resolution: item.selectedFormat.height,
            fileSize: outputPath?.fileSize,
            filePath: outputPath,
            downloadedAt: Date(),
            status: success ? .completed : .failed
        )
    )
```

#### HistoryView UI

```
┌────────────────────────────────────────────────────┐
│  ← 보관함    다운로드 히스토리            🔍 검색  │
├────────────────────────────────────────────────────┤
│  [오늘 ▼]                                         │
│  ├ 14:23  아이브(IVE) - 해야 (HEYA)   starshipTV │
│  │        [1080p MP4 · 342 MB]  [📂] [🗑] [↻]   │
│  ├ 12:05  뉴진스 How Sweet         NewJeans      │
│  │        [audio MP3 · 8 MB]     [📂] [🗑] [↻]   │
│                                                    │
│  [어제 ▼]                                          │
│  ├ 23:10  aespa Supernova           aespa         │
│  │        [2160p MP4 · 1.2 GB]     [📂] [🗑] [↻]  │
│                                                    │
│  [이번주 ▼]                                        │
│  ...                                               │
└────────────────────────────────────────────────────┘
```

- **검색**: 제목/채널명 검색
- **필터**: 오늘 / 어제 / 이번주 / 이번달 / 전체
- **우클릭 메뉴**: Finder에서 보기 / 삭제 / 다시 다운로드
- **데이터**: 앱 삭제 시까지 유지 (개별 삭제 가능)

---

## 13. v2.7.1 — 디버그 로그 UI 개선 + v2.7.2 — 설정 재구성 + 재생 속도 개선

### v2.7.1 (2026-07-22)

#### DebugLogView
- **자동스크롤 토글**: 기존 checkbox 스타일 → `arrow.down.to.line` SF Symbol image toggle로 변경, Pin 버튼 우측으로 이동
- **하단 버튼 크기 정규화**: 4개 버튼에서 `.controlSize(.small)` 제거 — 일관된 크기로 통일

#### 단축키
- **Cmd+D**: 디버그 로그 창 열기 단축키 추가 (`AppDelegate.swift` keyMonitor)
- **Cmd+, keyCode 버그 수정**: Space(49) → Comma(43) — `NSEvent.keyCode`가 Space를 반환하던 문제
- **툴바 드롭다운 통합**: MainView.swift — 3개 개별 툴바 버튼을 `Menu("영상 다운로드")` 하나로 통합

### v2.7.2 (2026-07-22)

#### 설정 4탭 → 5탭 (SettingsView.swift)

| 이전 (v2.7.1) | 이후 (v2.7.2) |
|---------------|---------------|
| 일반 | 다운로드 |
| 저장 | 저장 |
| 시스템 | 알림 신규 (신설) |
| AI 설정 | 시스템 |
| — | AI 설정 |

- **"채널 업데이트 알림"** → **"알림 신규" 탭으로 이동**, 이름 변경: "채널 업데이트 확인"
- 기존 시스템 탭의 11개 혼합 항목을 다운로드/알림/시스템에 적절히 재배치
- `SettingsTab` enum: `.general` → `.downloads`, `.notifications` (신규) 추가, 기존 4개 rawValue 업데이트

#### ChannelUpdateService — Combine observer
- `store.publisher.map(\.settings.showChannelBadge).removeDuplicates().sink` 구독
- OFF: 타이머 중단(resetTimer), 뱃지 초기화, API 미호출
- ON: 타이머 시작 + 즉시 채널 확인
- 기존: OFF여도 타이머는 계속 돌고 API 결과만 무시

#### StatusBarManager — 큐 항목 렌더링 수정
- `NSMenuItem`의 `action: nil`이 시스템에 의해 비활성화/흐리게(faded) 표시되는 문제
- `#selector(queueItemNoop)` + `target: self`로 변경, 항상 활성화
- 다운로드 상태와 무관하게 3개 큐 항목 항상 표시

#### PlayerView — 첫 재생 성능 개선
- `needsTranscoding()` 코덱 검사 방식 변경:
  - **이전**: `Process` + `ffprobe -v error -select_streams v:0 -show_entries stream=codec_name` + `waitUntilExit()` — 프로세스/파이썬/파일 I/O 5~10초 소요
  - **이후**: `AVURLAsset.loadTracks` + `load(.formatDescriptions)` — 순수 in-process, < 0.5초
- `codecCache`: static 딕셔너리 → **UserDefaults 저장** — 앱 재시작에도 코덱 캐시 유지

#### Format.best() — lower-first 포맷 선택 알고리즘
- **이전**: `exact → higher combined → exact video-only → exact any → first`
- **이후**: `exact → lower combined → higher combined → lower video-only → higher video-only → lower any → higher any → first`
- 모든 다운로더(Home/Batch/Channel)에 동일 적용
- ChannelContentView: `best[height<=N]` → `best[height<=N]/best` (fallback 추가)
- BatchDownloadView/ChannelContentView: 초기 해상도를 `settings.defaultResolution`에서 읽도록 수정 (`@State` init)


---

## 8. v3.0 설계 (신규 기능)

### 8.1 전역 검색 (자막·요약) — Phase A

- `DatabaseManager.searchContent(query:) -> [(videoId, matchedField, snippet)]`
  - 대상: `video_ai_data`(transcript, summary, subtitlesData) + `library`(title, channelName)
  - 구현: `LIKE '%query%'` 매칭, 매칭 문맥 60자 스니펫 추출 (SQLite FTS5는 규모상 보류)
- `LibraryReducer`:
  - `searchScope: .title / .content` State 추가 (기본 .title)
  - `.content`면 `filteredItems`를 `searchContent` 결과 videoId 목록으로 대체 + 스니펫 저장
  - 사이드바 검색창: 스코프 토글 버튼 + 결과 수 표시

### 8.2 플레이어 고도화 — Phase B

- `MPVClient` 추가 명령
  - `setPlaybackRate(_ rate: Double)` → `mpv_set_property("speed")`
  - `setABLoop(a:b:)` → `mpvCommand(["ab-loop-a", time])` / `["ab-loop-b", time]`
  - `clearABLoop()` → `["ab-loop-off"]`
- `PlayerReducer` State 추가: `playbackRate`, `aLoop: Double?`, `bLoop: Double?`, `queue: [PlayerItem]`, `queueIndex: Int`
  - `setQueue(items:startIndex:)`, `playNext`/`playPrevious`, `setPlaybackRate`, `setALoop`/`setBLoop`/`clearLoop`
  - 이전/다음 재생 시 `loadVideo(queue[i])` 재사용
- `PlayerView` 컨트롤바: 속도 메뉴(0.75/1.0/1.25/1.5/2.0), A/B 반복 버튼, 이전/다음 버튼, 자막 스타일(크기/색) 패널
- 자막 스타일: `SubtitleOverlay`에 `fontSize`/`textColor` 바인딩 (mpv 자막 스타일 대신 SwiftUI 오버레이)

### 8.3 홈 화면 위젯 — Phase C

- SwiftPM에 `TubeKeepWidget` app extension 타깃 추가 (WidgetKit)
- 앱 그룹 `group.com.tubekeep` App Group UserDefaults:
  - `widget_activeItems`: [id, title, progress, speed]
  - `widget_queueStats`: { downloading, waiting, completedToday }
  - `widget_recent`: [title, completedAt]
  - `AppReducer`/`DownloadQueueReducer` 상태 변경 시 기록 (`WidgetCenter.reloadAllTimelines()` 호출)
- `build_and_run.sh`: 위젯 번들을 `Contents/PlugIns/TubeKeepWidget.appex`에 포함 (release/debug 공통)
- 위젯 종류: 큐 진행률 링(medium), 진행 중 목록(large), 최근 완료(medium)

### 8.4 브라우저 통합 (scheme 확장) — Phase D

- `tubekeep://add?url=<encoded>` — 다운로더 창 열고 자동 정보 조회 (클립보드 감시와 동일 플로우)
- `tubekeep://open?id=<videoId>` — 해당 영상 요약/AI 창 열기
- `AppDelegate.application(_:open:)` — 기존 scheme 처리와 통합 (AppReducer에 액션 전달)
- Safari/Chrome 확장 앱은 별도 PLAN
