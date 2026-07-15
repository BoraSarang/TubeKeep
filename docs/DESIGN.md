# DESIGN — 기술 설계 문서

## 1. 아키텍처 개요

- **UI**: SwiftUI (macOS 13+)
- **아키텍처**: TCA 1.10 (The Composable Architecture)
- **백엔드**: yt-dlp (Process 호출)
- **메뉴바**: 순수 AppKit (NSStatusBar + NSView)
- **SPM** 모듈, swift-tools-version: 5.9
- **단일 .app**: `TubeKeep.app` (LSUIElement)
- **지원 칩셋**: Apple Silicon (ARM64) 전용 — Intel Mac은 Rosetta 포함 미지원
- **빌드 아키텍처**: ARM64 only (Apple Silicon 호스트); 유니버셜 빌드 시 Xcode + `--arch arm64 --arch x86_64` 필요
- **런타임 의존성**: ffmpeg + yt-dlp (앱 번들 `Contents/Resources`에 포함, 번들 우선 → brew → PATH 순서)
- **데이터 공유**: `UserDefaults(suiteName:)`으로 프로세스 간 공유 (마이그레이션 완료)
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
struct State: Equatable {
    var home = HomeReducer.State()
    var downloadQueue = DownloadQueueReducer.State()
    var settings = SettingsReducer.State()
    var statusBar = StatusBarReducer.State()
    @Presents var channelDownload: ChannelReducer.State?
    var library = LibraryReducer.State()
    var alwaysOnTop: Bool = false
}
```

#### Action
```swift
enum Action: Equatable {
    case home(HomeReducer.Action)
    case downloadQueue(DownloadQueueReducer.Action)
    case settings(SettingsReducer.Action)
    case statusBar(StatusBarReducer.Action)
    case channelDownload(PresentationAction<ChannelReducer.Action>)
    case library(LibraryReducer.Action)
    case toggleAlwaysOnTop
    case clipboardDetected(String)
    case appDidFinishLaunching
    case channelFetchInfo(String)
}
```

#### 브릿지 로직
- `downloadCompleted(id, success)` → `LibraryItem` 생성 → `LibraryCacheService.addItem` → `.library(.loadFromDisk)` 재로드
- `addToQueueResponse` → id별 `startDownload` 디스패치 (여유 슬롯)
- `playlistSelection(.confirmSelection)` → 선택 항목 일괄 추가
- `channelDownload(.addToQueue)` → downloadQueue.addItems
- `updateProgress` / `(removeItem|clearCompleted|clearAll)` → statusBar 동기화
- `settings(.setConcurrentDownloads)` → downloadQueue.maxConcurrent 동기화
- `appDidFinishLaunching` → UserDefaults에서 설정 로드

### 2.2 HomeReducer

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
    var clipboardMonitoring: Bool
}
```

**CancelID**: `.fetch`, `.fetchTimer`

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
    var concurrentDownloads: Int = 2
    var outputDirectory: String = "~/Downloads"
    var filenameTemplate: String = "{channel} - {index} - {title}"
    var limitRate: Int = 0
    var playSoundOnComplete: Bool = true
    var clipboardMonitoring: Bool = true
    var defaultResolution: Int = 480
    var maxRetries: Int = 3
    var launchAtLogin: Bool = false
    var maxUploadCheck: Int = 500
    var skipIndexOnFailure: Bool = false

    // alwaysOnTop은 영상 다운로더 창 전용 (AppReducer.alwaysOnTop)
    // 설정 창에서는 비활성화 표시
}
```

저장: UserDefaults JSON (`appSettings` 키).
- `AppReducer`가 전역 공유 상태(`state.settings`)로 관리 → 모든 기능에서 즉시 반영
- `DownloadQueueReducer`에 `outputDirectory`, `filenameTemplate` 동기화 필드 추가
- `DownloadManager`에 `updateSettings` 시 별도 캐싱 (`outputDirectory`, `filenameTemplate`)

### 2.5 StatusBarReducer

```swift
struct State: Equatable {
    var statusText = "대기중"
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
@ObservableState
struct State: Equatable {
    var items: [LibraryItem] = []
    var searchText = ""
    var selectedChannel: String? = nil
    var sortOrder: LibrarySortOrder = .dateDesc
    var filterMode: LibraryFilterMode = .all
    var viewMode: LibraryViewMode = .grid
    var isLoading = false
    var selectedIds: Set<String> = []  // T-112: 다중 선택
}
```
- `viewMode`는 UserDefaults(`libraryViewModeKey`)에 저장되어 재실행 시 유지
- `selectedIds`: Cmd+클릭으로 토글, selection bar에서 일괄 삭제 시 사용

#### Action
```
loadFromDisk / itemsLoaded / addItem / removeItem / removeSelected
setSearchText / setSelectedChannel / setSortOrder / setFilterMode / setViewMode
openFile / revealInFinder
downloadSubtitles / subtitleResult        // T-116: 자막 다운로드
toggleSelection / selectAll / clearSelection  // T-112: 다중 선택
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
| 설정 | `"settings"` | 480×580 | 480×400 | 가로 고정 (480px), 세로만 가능 | 비활성화 |
| **설정** | `"settings"` | **480×580** | **480×400** | **세로만 (가로 고정)** | **비활성화** |

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
struct LibraryItem: Identifiable, Equatable, Codable {
    let id: String          // videoId
    let title: String
    let channelId: String
    let channelName: String
    let thumbnailURL: String
    let filePath: String
    let downloadDate: Date
}
```

### 4.2 LibrarySortOrder
```swift
enum LibrarySortOrder: String, Equatable, CaseIterable {
    case dateDesc = "최신순"
    case dateAsc = "오래된순"
    case titleAsc = "제목순"
    case channelAsc = "채널순"
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

### 5.5 LibraryCacheService (actor)
- **Library 데이터**: `UserDefaults(suiteName: "com.tubekeep.shared")` → `"downloadLibrary"` 키에 `[videoId: LibraryItem]` JSON
  - `loadItems()` → [LibraryItem]
  - `addItem(LibraryItem)` / `removeItem(id:)`
  - **동기화**: UserDefaults(suiteName:)으로 데이터 일관성 유지
- **마이그레이션**: TubeKeep.app 첫 실행 시 `UserDefaults.standard`에 저장된 데이터를 `UserDefaults(suiteName:)`로 자동 이전
- **썸네일 캐시**: NSCache(메모리) + `~/Library/Caches/com.tubekeep/thumbnails/` (디스크)
  - `cachedThumbnail(for:)` / `loadThumbnail(from:videoId:)` / `placeholderThumbnail()`
  - YouTube CDN URL → 다운로드 → 로컬 캐시 → placeholder
- **아바타 캐시**: 동일 디렉토리 `avatars/` 하위
  - `cachedAvatar(for:)` / `cacheAvatar(for:data:)` / `placeholderAvatar()`
- **채널명 집계**: `channelNames(from:)` → `[(id, name, count)]`
- **디스크 사용량**: `calculateDiskUsage()` → Int64 (static)
  - FileManager.enumerator로 `storageDirectory` + `~/Library/Caches/com.tubekeep/` 순회, 파일 크기 합산
  - 비동기 연산 (Task 내 호출)
  - LibraryReducer.diskUsageBytes에 저장

### 5.6 ChannelFetchService (actor)
- `fetchChannelInfo(url:)` → SubscribedChannel
  - videoCount는 UU playlist의 `playlist_count` 사용 (fallback 실패 시 0)
  - 호출자는 `videoCount: 0`인 경우 기존 값을 보존해야 함
- `fetchAllVideos(channelId:handle:)` → ([ChannelVideoItem], totalCount)
  - URL: `@handle/videos` (숏츠 제외), handle 없으면 UU 플레이리스트 폴백
  - 회원전용 제외: JSON 필드 `availability == "subscriber_only"` 제외
  - 반환: `(videos, videos.count)` — 필터링된 실제 표시 개수
- `fetchAvatarURL(channelId:)` → String?
- yt-dlp flat-playlist + dump-json 사용

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
- 메뉴바 "설정..." (⌘,) + 모든 창에서 접근 가능
- 영상 다운로더/일괄 다운로더/채널 다운로더/라이브러리 모두에서 공통 사용
- `alwaysOnTop`은 영상 다운로더 창 전용이므로 설정 창에서 비활성화 표시
- 창 크기: 가로 480px 고정, 세로 580px (`contentMinSize` / `contentMaxSize` / `setContentSize`)

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

## 7b. DebugLogView (DEBUG 전용)

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

## 9. 파일 목록 (38 Swift 파일)

### App/ (5)
| 파일 | 설명 |
|------|------|
| `TubeKeepApp.swift` | `@main` entry point, `SwiftUI.Settings` 씬 연결 |
| `AppDelegate.swift` | 메뉴바, 4개 윈도우, 단축키, 클립보드, 속도측정 |
| `AppReducer.swift` | Root TCA reducer, 브릿지 로직 |
| `VideoDownloadView.swift` | 영상 다운로더 메인 뷰 (Home+Queue) |
| `StatusBarView.swift` | StatusBarReducer (메뉴바 상태) |

### Features/ (16)
| 파일 | 설명 |
|------|------|
| `Home/HomeReducer.swift` | URL 입력 + 정보 조회 reducer |
| `Home/HomeView.swift` | URL 입력 + 정보 카드 + 포맷 선택 UI |
| `BatchDownload/BatchDownloadView.swift` | 일괄 다운로더 UI |
| `PlaylistSelection/PlaylistSelectionReducer.swift` | 플레이리스트 선택 reducer |
| `PlaylistSelection/PlaylistSelectionView.swift` | 플레이리스트 시트 UI |
| `Channel/ChannelContentView.swift` | 채널 콘텐츠 (헤더+비디오목록+다운로드) |
| `Channel/ChannelDownloaderView.swift` | 채널 다운로더 창 root |
| `Channel/ChannelListView.swift` | 채널 목록 사이드바 |
| `Settings/SettingsReducer.swift` | 설정 reducer |
| `Settings/SettingsView.swift` | 설정 UI |
| `Library/LibraryReducer.swift` | 라이브러리 reducer (sort/filter/viewMode) |
| `Library/MainView.swift` | 라이브러리 root (sidebar + content + toolbar) |
| `Library/LibrarySidebarView.swift` | 사이드바 (검색/필터/채널목록) |
| `Library/LibraryGridView.swift` | 그리드 모드 + LeftClickMenu + 빈 상태 |
| `Library/LibraryListView.swift` | 목록 모드 |
| `DownloadQueue/DownloadQueueReducer.swift` | 다운로드 큐 reducer |
| `DownloadQueue/DownloadQueueView.swift` | 다운로드 큐 UI |

### Services/ (6)
| 파일 | 설명 |
|------|------|
| `YouTubeDLService.swift` | yt-dlp 정보 조회 actor |
| `DownloadManager.swift` | 다운로드 프로세스 관리 (OSAllocatedUnfairLock) |
| `ProcessRunner.swift` | async Process 실행 |
| `LibraryCacheService.swift` | 라이브러리 + 썸네일/아바타 캐시 actor |
| `ChannelFetchService.swift` | 채널 정보 fetch actor |
| `UploadOrderService.swift` | 업로드 순번 조회 actor |

### Models/ (8)
| 파일 | 설명 |
|------|------|
| `LibraryItem.swift` | LibraryItem + SortOrder + FilterMode + ViewMode |
| `VideoInfo.swift` | YouTube 영상 메타데이터 |
| `DownloadItem.swift` | 다운로드 작업 모델 |
| `Format.swift` | 비디오 포맷 |
| `Settings.swift` | 설정 모델 |
| `SubscribedChannel.swift` | 구독 채널 모델 |
| `ChannelModels.swift` | 채널 비디오 + 캐시 |
| `BatchPreset.swift` | 일괄 다운로드 프리셋 |

### Helpers/ (2)
| 파일 | 설명 |
|------|------|
| `Constants.swift` | 앱 상수 + 유틸리티 |
| `WindowAccessor.swift` | alwaysOnTop modifier |

### Debug/ (2) — DEBUG 전용
| 파일 | 설명 |
|------|------|
| `DebugLogManager.swift` | `ObservableObject` 로그 관리자 (타임스탬프 자동 추가) |
| `DebugLogView.swift` | SwiftUI 로그 뷰 (자동 스크롤, 복사 가능) + `debugLogOverlay` View extension |

### Build/ (1)
| 파일 | 설명 |
|------|------|
| `build_and_run.sh` | 빌드 스크립트 — 단일 바이너리 → `TubeKeep.app` 번들 생성 |

---

## 10. 데이터 저장 키 총정리

| 키 | 타입 | 내용 | 저장소 |
|----|------|------|--------|
| `"appSettings"` | JSON | Settings (concurrentDownloads, outputDirectory, ...) | UserDefaults.standard |
| `"downloadLibrary"` | JSON | `[videoId: LibraryItem]` | UserDefaults(suiteName:) |
| `"libraryViewMode"` | String | `"grid"` or `"list"` | UserDefaults.standard |
| `"channelOrder"` | JSON | `[String]` 채널 ID 정렬 순서 (T-117) | UserDefaults.standard |
| `"subscribedChannels"` | JSON | `[SubscribedChannel]` | UserDefaults.standard |
| `"channelDownloads"` | [String] | 다운로드 완료된 videoId 목록 | UserDefaults.standard |
| `"channelFetchTimestamps"` | [String: Date] | 채널별 마지막 fetch 시간 | UserDefaults.standard |
| `"channelVideosData"` | JSON | 채널별 비디오 목록 캐시 | UserDefaults.standard |
| `"channelsNewVideos"` | JSON | `[channelId: [videoId]]` 채널별 미확인 새 영상 ID 목록 (T-114) | UserDefaults.standard |
| `"channelsSeenVideoIds"` | JSON | `[channelId: [videoId]]` 채널별 확인 완료 영상 ID 목록 (T-114) | UserDefaults.standard |
| `"downloadQueue"` | JSON | `[DownloadItem]` 큐 영속성 (T-115) | UserDefaults.standard |

- `UserDefaults(suiteName: "com.tubekeep.shared")`는 라이브러리 데이터 공유용
