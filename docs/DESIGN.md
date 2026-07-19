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
│  글로벌단축키 / 클립보드감시 / 속도측정  │
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
    var defaultResolution: Int = 480
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
    var speedTestState: SpeedTestState = .idle  // .idle / .running / .done(speed)
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
인터넷 속도 측정    → startSpeedTest
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

### 5.2 DownloadManager (class, singleton)
- `startDownload(item:)` → Process 시작
- `pauseDownload(id:)` / `resumeDownload(id:)` / `cancelDownload(id:)`
- `activeProcesses` → `OSAllocatedUnfairLock`으로 스레드 세이프
- 진행률 파싱: stderr에서 `[download] N.N%` 추출
- 완료 시 NSSound("Glass") 재생

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
- **v2.2.0**: 4탭 레이아웃 (일반/저장/시스템/AI 요약) — 좌측 140pt 사이드바 + 우측 ScrollView
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
- 각 window의 동작을 실시간 로그로 확인
- 창 생성/포커스/닫힘/버튼 클릭 등 주요 이벤트 기록
- **DEBUG 빌드에서만 컴파일** (#if DEBUG)

### DebugLogManager (class, ObservableObject)
```swift
#if DEBUG
final class DebugLogManager: ObservableObject {
    @Published var logs: [String] = []
    
    func append(_ message: String) {
        let ts = DateFormatter()
        ts.dateFormat = "HH:mm:ss.SSS"
        logs.append("[\(ts.string(from: Date()))] \(message)")
    }
    
    func clear() { logs.removeAll() }
}
#endif
```
- 각 window마다 독립적인 인스턴스
- AppDelegate 프로퍼티에 저장되어 AppDelegate도 직접 로그 추가 가능
- View에 `@ObservedObject`로 전달

### DebugLogView (SwiftUI View)
```swift
#if DEBUG
struct DebugLogView: View {
    @ObservedObject var manager: DebugLogManager
    
    body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(manager.logs.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(size: 9, design: .monospaced))
                                .textSelection(.enabled)  // 복사 가능
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(6)
                    .onChange(of: manager.logs.count) { _ in
                        withAnimation { proxy.scrollTo(manager.logs.count - 1, anchor: .bottom) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 120)
                .background(Color(.textBackgroundColor))
            }
            Divider()
            HStack {
                Button("복사") { /* NSPasteboard */ }.controlSize(.small)
                Button("지우기") { manager.clear() }.controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 2)
        }
    }
}
#endif
```

### 통합 방식
- 각 window의 SwiftUI root view 최하단에 `DebugLogView` 추가
- AppDelegate에서 window 생성 시 `DebugLogManager`를 만들어 view에 주입 + AppDelegate에도 저장
- 주요 로그 포인트:
  - window 생성/재사용/닫힘
  - makeKeyAndOrderFront / NSApp.activate
  - distributed notification 송수신
  - clipboard 감지 → autoFetch
  - URL scheme 처리

### 파일 위치
```
Sources/MDownload/Debug/
├── DebugLogManager.swift
└── DebugLogView.swift
```

## 8. Constants

```swift
enum Constants {
    static let appName = "TubeKeep"
    static let defaultResolution = 480
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

    // Notification Center (내부)
    static let openMainWindowNotification = Notification.Name("com.tubekeep.openMainWindow")
    static let openDownloaderWindowNotification = Notification.Name("com.tubekeep.openDownloaderWindow")
    static let openBatchWindowNotification = Notification.Name("com.tubekeep.openBatchWindow")
    static let openChannelWindowNotification = Notification.Name("com.tubekeep.openChannelWindow")

    // yt-dlp
    static var ytDlpPath: String { get }  // 번들 → brew → PATH
    static var ffmpegPath: String { get } // 번들 → brew → PATH
    static var youtubeExtractorArgs: String { get } // "youtube:lang=XX" (시스템 언어 기반)

    // URL utils
    static func isChannelURL(_ url: String) -> Bool
    static func channelIDFromURL(_ url: String) -> String?
    static func sanitizeFolderName(_ name: String) -> String
}
```

---

## 9. 파일 목록 (61 Swift 파일)

### App/ (9)
| 파일 | 설명 |
|------|------|
| `TubeKeepApp.swift` | `@main` entry point, 빈 SwiftUI Scene |
| `AppDelegate.swift` | 메뉴바, 4개 윈도우, 단축키, 클립보드, URL scheme |
| `AppReducer.swift` | Root TCA reducer, 브릿지 로직 |
| `VideoDownloadView.swift` | 영상 다운로더 메인 뷰 (Home+Queue) |
| `StatusBarView.swift` | StatusBarReducer (메뉴바 상태) |
| `StatusBarManager.swift` | 메뉴바 상태 관리 + 메뉴 구성 (v2.4.0 AppDelegate 분리) |
| `ClipboardMonitor.swift` | 클립보드 감시 + NSPanel 알림 (v2.4.0 AppDelegate 분리) |
| `ChannelUpdateService.swift` | 채널 업데이트 30분 타이머 폴링 (v2.4.0 AppDelegate 분리) |
| `FixedWidthWindowController.swift` | 라이브러리 창 가로 840px 고정 |

### Features/ (21)
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
| `Settings/SettingsReducer.swift` | 설정 reducer (v2.2.0: 4탭) |
| `Settings/SettingsView.swift` | 설정 UI (SettingsRow 제네릭 컴포넌트) |
| `Library/LibraryReducer.swift` | 라이브러리 reducer (v2.5.x: podcast/Q&A/mindmap) |
| `Library/MainView.swift` | 라이브러리 root (sidebar + toolbar + AIWindowView) |
| `Library/LibrarySidebarView.swift` | 사이드바 (검색/필터/채널목록/디스크사용량) |
| `Library/LibraryGridView.swift` | 그리드 모드 + LeftClickMenu + 빈 상태 |
| `Library/LibraryListView.swift` | 목록 모드 |
| `Library/QAView.swift` | Q&A UI (v2.5.3) |
| `Library/MindmapView.swift` | 마인드맵 트리 UI (v2.5.4) |
| `DownloadQueue/DownloadQueueReducer.swift` | 다운로드 큐 reducer |
| `DownloadQueue/DownloadQueueView.swift` | 다운로드 큐 UI |
| `Discover/DiscoverView.swift` | 트렌딩/검색 카드 그리드 (v2.0.0) |

### Services/ (20)
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
| `DatabaseManager.swift` | SQLite DB 관리 (video_ai_data + qna_history 테이블) |
| `PersistenceController.swift` | SwiftData ModelContainer 관리 (v2.4.0) |
| `SwiftDataMigration.swift` | UserDefaults → SwiftData 자동 마이그레이션 (v2.4.0) |
| `EdgeTTSClient.swift` | Edge TTS API 클라이언트 (실험적) |
| `ErrorMessageMapper.swift` | yt-dlp 에러 메시지 한글 매핑 (v2.3.0) |

### Models/ (12)
| 파일 | 설명 |
|------|------|
| `LibraryItem.swift` | `@Model class` — SwiftData 영구 저장 (sortOrder/filterMode/viewMode enum 포함) |
| `VideoInfo.swift` | YouTube 영상 메타데이터 |
| `DownloadItem.swift` | 다운로드 작업 모델 |
| `Format.swift` | 비디오 포맷 |
| `Settings.swift` | 설정 모델 (SettingsTab enum 포함) |
| `SubscribedChannel.swift` | `@Model class` — 구독 채널 SwiftData 모델 |
| `ChannelModels.swift` | 채널 비디오 + 캐시 |
| `BatchPreset.swift` | 일괄 다운로드 프리셋 |
| `TrendingVideo.swift` | 트렌딩 영상 + TrendingCategory 열거형 (systemIcon) |
| `PodcastModels.swift` | PodcastScript, PodcastSegment, PodcastResult |
| `QAModels.swift` | QAResponse, QATimestamp, QAHistoryItem |
| `MindmapModels.swift` | MindmapNode (재귀적 Codable, Custom CodingKeys) |

### Helpers/ (4)
| 파일 | 설명 |
|------|------|
| `Constants.swift` | 앱 상수 + 유틸리티 (keyCode 기반 단축키) |
| `WindowAccessor.swift` | alwaysOnTop NSViewRepresentable modifier |
| `BookmarkManager.swift` | Security-scoped bookmark 관리 (저장 폴더 접근 권한) |
| `ImageCacheEnvironmentKey.swift` | EnvironmentKey 기반 캐시 주입 |

### Debug/ (2) — DEBUG 전용
| 파일 | 설명 |
|------|------|
| `DebugLogManager.swift` | `ObservableObject` 로그 관리자 (타임스탬프 자동 추가) |
| `DebugLogView.swift` | SwiftUI 로그 뷰 (자동 스크롤, 복사 가능) |

### Views/ (1)
| 파일 | 설명 |
|------|------|
| `CachedImageViews.swift` | CachedThumbnailView + CachedAvatarView 공유 컴포넌트 |

### Build/ (1)
| 파일 | 설명 |
|------|------|
| `build_and_run.sh` | 빌드 스크립트 — debug/release + yt-dlp/ffmpeg 번들링 + 설치 + 실행 |

---

## 10. 데이터 저장 키 총정리

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
