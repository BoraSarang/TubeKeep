# AGENTS.local.md — TubeKeep 프로젝트 특화 가이드

> 이 파일은 공통 `AGENTS.md`를 확장한다.
> TubeKeep 프로젝트에서만 적용되는 규칙을 정의한다.
> 공통 규칙과 충돌 시 이 파일이 우선한다.

**프로젝트명**: TubeKeep (YouTube 다운로더 + 라이브러리 + AI 요약)
**기술 스택**: SwiftUI, TCA (The Composable Architecture), SwiftData, SQLite, yt-dlp
**번들**: `LSUIElement = true` (메뉴바 에이전트 앱)

---

## 0. 개인 프로젝트 원칙 — 1인 전용

> **이 프로젝트는 오직 나(제작자) 혼자만을 위해 만든 개인 프로그램이다.**
> 모든 결정, 설계, 구현의 최우선 기준은 **내 편의성과 내 취향**이다.

### 0.1 사고방식
- "일반 사용자", "초보자", "대중"이라는 개념은 존재하지 않음
- UI/UX: **내가 편한 대로**. 남들 헷갈리든 말든 상관없음
- 기능 추가: **내가 필요한 것만**. "혹시 다른 사람이..."라는 고려 안 함
- 코드 품질: 유지보수 가능한 선에서 타협 가능. 깔끔한 것보다 빠른 게 우선
- 검증: **내가 쓰는데 문제 없으면 OK**. 엣지 케이스 100% 커버 불필요
- 디자인: **내 취향 1순위**. macOS HIG 가이드라인은 참고만
- 설정/단축키: 내 손에 익은 대로

### 0.2 적용 예
- 사이드바 채널 정보 표시, 리포트 UI 등은 전적으로 내 취향대로
- 기능 제안 시 "보통 사용자는..." 대신 "네가 쓰기에 편리한가?"가 기준
- 테스트는 내가 실제 쓰는 시나리오만 커버
- 버그여도 내가 겪지 않는 건 우선순위 낮음

---

## 1. 프로젝트 문서 구조

### 핵심 문서 (docs/)

| 파일 | 목적 |
|------|------|
| `PRD.md` | 제품 요구사항 |
| `DESIGN.md` | 기술 설계 |
| `PLAN.md` | 전체 로드맵 (plans/ 폴더 링크만 포함) |
| `TODO.md` | 작업 추적 (T-번호) |
| `CHANGELOG.md` | 버전별 변경 이력 |

### 참조 문서

| 파일 | 내용 |
|------|------|
| `archive/BRAND.md` | 앱 이름, 슬로건, 브랜드 무드 (과거 문서 보관) |
| `archive/UI_DESIGN.md` | 사이드바 네비게이션, Discover 탭, AI 요약 UI (과거 문서 보관) |
| `IMAGE_CACHING.md` | 이미지 캐시 전략, 디렉토리 구조 |

### API 문서 (api/)

| 파일 | API | 상태 |
|------|-----|------|
| `api/SETUP_GEMINI.md` | Google Gemini | 현재 사용 |
| `api/SETUP_OLLAMA.md` | Ollama | 레거시 (v2.1.0 이후 미사용) |
| `api/AX4_ANALYSIS.md` | SKT A.X 4.0 | 현재 사용 |

### 계획/테스트 문서

```
docs/
├── plans/
│   ├── PLAN_v3.0_macos.md
│   ├── PLAN_v3.1_macos.md
│   ├── PLAN_v3.2_macos.md   # 현재 작업 버전
│   └── archive/             # 완료된 구버전 보관 (v2.x)
├── tests/
│   ├── v3.1.1.md
│   ├── results/             # 자동/수동 테스트 결과 (auto-test-*.md)
│   └── archive/             # 완료된 구버전 보관 (v2.x)
├── web/                     # 랜딩 사이트 (index.html, style.css, app-icon.png)
├── screenshots/{platform}/  # a11y-dump 3종 세트 (.a11y.txt/.storage.json/.perf.json)
├── api/                     # API 설정 문서
├── DESIGN_SYSTEM.md         # 디자인 시스템 정의서
└── archive/                 # BRAND.md, UI_DESIGN.md, 2.7.7_summary.md 보관
```

- 스크립트는 **루트 `scripts/` (소문자) 한 곳**에 통합: `build_and_run.sh` 디스패처가 `scripts/*.sh`를 호출
- 완료된 버전은 `plans/archive/`, `tests/archive/`로 이동, 활성 버전은 최상위 유지

- **계획 문서 필수 섹션**: 개요, 결정 사항, 아키텍처, 구현 단계(T-번호), State/Action 설계(TCA Reducer), UI 통합, 테스트 계획(TC-번호)
- **테스트 문서 형식**: 빌드 명령어, 전제조건, TC별 절차/기대결과, 결과 요약표

---

## 2. 빌드 및 실행

```bash
# 디버그 빌드 및 실행 (권장)
make

# 릴리즈 빌드
make release

# 직접 호출 (v1.7 디스패처)
./build_and_run.sh debug macos
./build_and_run.sh release macos --no-launch
```

- 빌드 후 `~/Applications/TubeKeep.app` 생성 확인
- `make` = `./build_and_run.sh debug macos` = `scripts/build-macos.sh debug`
- `outputDirectory`는 UserDefaults + security-scoped bookmark로 관리

## 3. TCA 및 상태 관리 규칙

- 모든 기능은 TCA Reducer로 구현: `LibraryReducer`, `DownloadQueueReducer`, `StatusBarReducer` 등
- State/Action 설계 시 `docs/plans/PLAN_v{버전}.md`에 먼저 정의
- `AppReducer`에서 자식 Reducer 간 이벤트 전달 (예: downloadCompleted → calculateDiskUsage)

## 4. 데이터 저장 규칙 (v2.5.0 이후)

**AI 요약/자막은 SQLite에만 저장 (SwiftData는 다운로드한 영상 메타만)**

- 요약 요청 흐름: `SummarizationService.summarizeVideo()` → `DatabaseManager.shared.loadVideoAIData()` 캐시 확인 → 있으면 반환 / 없으면 API 폴백 체인
- 저장: `DatabaseManager.shared.updateSummary()` + SwiftData 동시 저장 (다운로드 영상만)
- 자막 확인: `LibraryReducer.hasSubtitles(for:)`는 파일시스템이 아니라 SQLite에서 확인
- `LibraryItem.id` = YouTube videoId = DB 키

**흐름도:**
```
자막 다운로드 → 임시 파일 → 파싱 → DatabaseManager.updateTranscript() → 임시 파일 삭제
AI 요약 요청 → DB 캐시 확인 → 있으면 즉시 반환 / 없으면 API 호출 → DatabaseManager.updateSummary()
```

## 5. TubeKeep 특화 트러블슈팅 (필수 숙지)

원본 AGENTS.md의 시행착오 기록 중 핵심만 이관.

### 5.1 DownloadManager 동시성 이슈
- **문제**: `startDownload()`에서 mutable state를 Lock 없이 접근 시 race condition
- **해결**: `ManagerState` struct + `stateLock`(`OSAllocatedUnfairLock`) 도입
  - 진입 시 Lock에서 값 복사 후 지역 변수만 사용
  - `buildDownloadArgs()`/`constructOutputTemplate()`는 파라미터로 값 전달

### 5.2 LSUIElement 앱 단축키 이슈 (CMD+V/C/X/A)
- **증상**: CMD+V 시 경고음, 우클릭 붙여넣기는 정상
- **원인**: `LSUIElement = true` 앱은 메인 메뉴 바가 없어 `keyEquivalent`를 못 찾음
- **해결**: `AppDelegate.applicationDidFinishLaunching`에서 `NSEvent.addLocalMonitorForEvents`로 직접 가로채기
- **⚠️ 한글 키보드 주의**: `event.charactersIgnoringModifiers`는 한글 반환 (`c`→`ㅍ`), 반드시 `event.keyCode` 사용
  - `0`=A, `7`=X, `8`=C, `9`=V, `49`=,
- `.commands` 수정자는 `LSUIElement` 앱에서 불안정 → 이벤트 모니터 방식 사용

```swift
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    if event.modifierFlags.contains(.command) {
        switch event.keyCode {
        case 7: NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil); return nil
        case 8: NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil); return nil
        case 9: NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil); return nil
        case 0: NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil); return nil
        default: break
        }
    }
    return event
}
```

### 5.3 채널 업데이트 알림 (T-114 계열)
- `AppDelegate.startChannelUpdateCheck` (30분 타이머) → `ChannelFetchService.fetchAllVideos`
- `seenVideoIds` / `newVideoIds` 분리: 채널 선택/새로고침 시 `newIds → seenIds` 이동 → 다운로드 안 해도 재감지 방지
- StatusBar badge는 사용자 클릭 시까지 유지 (autoReset 금지)
- 상태바 텍스트: `statusBar.updateStatusText` 액션으로 "업데이트 확인 중 (N/M) — 채널명" 표시
- 로그는 `channelLogManager` → `libraryLogManager`로 통합

### 5.4 디스크 사용량
- `LibraryCacheService.calculateDiskUsage()` : `outputDirectory` + 캐시 디렉토리 `FileManager.enumerator` 합산
- `LibraryReducer`: `diskUsageBytes: Int64` + `calculateDiskUsage` / `diskUsageUpdated` 액션
- 사이드바 하단 표시: `[폴더] Finder에서 보기  12.3 GB  ↻` (↻ = 수동 새로고침)
- 포맷팅: `ByteCountFormatter`

### 5.5 mpv 재생 크래시 (macOS 26, bd TubeKeep-e5i)
- **증상**: mpv 렌더 스레드(`com.borasarang.mpv.render`)에서 OpenGL→Metal 드라이버 크래시 (SIGSEGV @0x28, `_MTLDevice supportsFamily`)
- **원인**: mpv 0.41 `MPV_RENDER_API_TYPE_OPENGL` + `hwdec=videotoolbox` GPU 경로가 macOS 26.5.2에서 드라이버 내부 크래시
- **임시 조치 (적용됨)**: `MPVClient.setupMPV()`에서 `hwdec=no`로 변경 → CPU 디코딩, 재현되지 않음
- **주의**: 성능 영향 있음 (고해상도 프레임 드랍 가능). 재현 조건 불명확, SW 렌더링(`MPV_RENDER_API_TYPE_SW`) 전환이 확실한 회피책
- **참조**: `Sources/TubeKeep/Features/Player/MPVClient.swift`

### 5.6 클립 썸네일 미생성: PNG 코덱 소스에서 `-ss` 시크 불가 (bd TubeKeep-2gk)
- **증상**: 클립 목록에 이미지 없음 (film.stack placeholder만 표시). `Clips/<videoId>/thumb.jpg` 부재
- **원인**: PNG 코덱 비디오(화면 녹화/임포트 파일, 예: `조선힙합.cU1rgvWwSas.mp4`)는 프레임에 타임스탬프가 없어 ffmpeg `-ss` 시크가 즉시 "no packets"로 실패 (타임아웃 아님, 즉시 실패). 기존 코드는 stderr를 `nullDevice`로 버려 실패를 은폐
- **조치 (적용됨, `ClipService.swift`)**: `-ss`를 `-i` 뒤로 이동, 타임아웃 120s, stderr Pipe 캡처 → 실패 시 `[Clip]` 로그, 실패 시 `time=0` 첫 프레임으로 fallback (0.07s 성공). `regenerateThumbnailsIfNeeded()` 신설 → `MainView.onAppear`에서 기존 클립 백필
- **특이사항**: h264/av1은 `-ss` 시크 정상(0.34s). `videoId=="unknown"` 클립은 원본 소스 매칭 불가 → 썸네일 백필 스킵 (정상 동작)
- **참조**: `Sources/TubeKeep/Services/ClipService.swift`, `Sources/TubeKeep/Features/Library/MainView.swift`

## 6. TubeKeep 버전 진행 규칙

공통 규칙 + 추가:

- 테스트 파일: `docs/tests/v{버전}.md`
- 테스트 빌드 명령어는 문서 상단에 명시: `**빌드**: bash build_and_run.sh debug`
- TC 작성 시 **테스트 URL** 필수 (실제 YouTube URL 사용)
- 채널 기능 테스트 시 `channelOrder`, `downloadQueue` 등 UserDefaults 키 초기화 여부 명시

## 7. 기타 상수 및 서비스

**새 상수 예시:**
- `Constants.channelOrderKey`, `Constants.downloadQueueKey`

**서비스 메서드:**
- `LibraryCacheService.removeItems(ids:)`
- `LibraryCacheService.calculateDiskUsage()` (static)
- `StatusBarReducer.setBadgeCount`

---

## 9. 버그 관리

- 작업 전 항상 `bd list`로 열린 버그 확인
- 버그 발견 시 `bd create "제목" -t bug --notes "재현방법"`으로 등록
- 버그 수정 완료 시 `bd close <id>`로 반드시 닫기
- 절대 메모장 등에 따로 기록하지 말고 `bd`로만 관리

## 10. 플레이어 시스템 (v2.6.0+)

### PlayerMode
- `builtIn` — 자체 플레이어
- `systemDefault` — 기본 연결 프로그램
- 설정: 시스템 탭 picker → `Settings.playerMode`

### PlayerWindow
- 크기: 854×480 (480p), 패널 열리면 +320 = 1174×480, 리사이즈 불가
- `styleMask`: `[.titled, .closable, .resizable]`
- `collectionBehavior`: `.managed`, `.ignoresCycle`, `.fullScreenPrimary`
- `isReleasedWhenClosed = false`, `isRestorable = false`
- 전체 화면: 툴바 버튼 + 더블클릭 (`ZStack.onTapGesture(count:2)`)
- 종료: `close()` + `cleanupPlayer()` (pause + removeObserver + nil)

### NSPlayerView
- AVPlayerView + `autoresizingMask = [.width, .height]`
- `controlsStyle = .none` (v2.7.1에서 이중 컨트롤 해결)

## 11. 자막 시스템

### 우선순위
1. yt-dlp 다운로드 (timed VTT/SRT) — 항상 시도
2. 실패 시 → DB transcript + duration → 추정 타이밍 (`estimateSubtitles`)
3. duration 없으면 → DB transcript → 문장 분할 1초 간격 (`fallbackCues`)
4. HTML 엔티티 디코딩 + 마커 제거 (`>>`, `♪`, `[Music]` 등)

### DB transcript fallback
- 문장 단위 분할, 1초 간격 cue (duration 없어도 작동)

### HTML 디코딩
- `PlayerReducer.decodeHTMLEntities()` (static, fileprivate)

### yt-dlp flags
```
--skip-download --write-subs --write-auto-subs --sub-langs en,ko --convert-subs srt
```

### 디버깅
- stderr 캡처 + print 로그

## 12. 주요 파일

| 파일 | 역할 |
|------|------|
| `PlayerReducer.swift` | TCA reducer, 자막 로딩/파싱/디코딩 |
| `PlayerView.swift` | SwiftUI body, window size/panel toggle, GeometryReader + double-tap |
| `NSPlayerView.swift` | AVPlayerView NSViewRepresentable (autoresizingMask) |
| `SubtitleOverlay.swift` | 비디오 위 오버레이 |
| `SubtitlePanel.swift` | 사이드 패널 (로딩/에러/빈 상태) |
| `AppDelegate.swift` | playerWindow 생성/정리, fullScreenPrimary |
| `LibraryReducer.swift` | `openFile`/`openSelected`에 duration 전달 |
| `YouTubeDLService.swift` | `fetchStreamingURL()`, `fetchSubtitles()` |
| `Settings.swift` | `PlayerMode` enum |
| `SettingsView.swift` / `SettingsReducer.swift` | 시스템 탭 picker |
| `DebugLogManager.swift` / `DebugLogView.swift` | v1.7 DebugPanel — 7종 레벨, 5000줄, NSWindow 600×320, 📌 자동스크롤 |
| `ChannelDownloaderView.swift` | 공유 `DebugLogManager.shared` 사용 (자체 debugLogs 배열 제거됨) |

## 13. v2.7.1 주요 수정 사항 (Critical & High)

| 수정 내용 | 파일 | 설명 |
|-----------|------|------|
| Playlist URL 초기화 | `HomeReducer.swift` | `infoResponse`에서 `state.urlString` 클리어 시점을 playlist 체크 이후로 이동 |
| False 설정 복원 | `AppReducer.swift` | `playSoundOnComplete=false`, `clipboardMonitoring=false`가 앱 재시작 시 무시되던 버그 수정 |
| Actor 차단 해소 | `SummarizationService.swift` | `process.waitUntilExit()` → `terminationHandler` 기반 정적 메서드로 교체 |
| Data race | `BookmarkManager.swift` | `nonisolated(unsafe) var activeURLs` → `OSAllocatedUnfairLock` 동기화 |
| API 키 노출 | `MindmapService.swift` | `print` 구문에서 API 키 로그 제거, 모두 `log()`로 통일 |
| SRT 숫자 텍스트 누락 | `PlayerReducer.swift`, `WhisperService.swift`, `SummarizationService.swift` | `Int($0) == nil` 필터를 `seenTiming` 플래그로 대체 |
| 이중 컨트롤 | `NSPlayerView.swift` | `controlsStyle = .default` → `.none` |
| 하드코딩 API 키 | `Constants.swift` | `defaultAX4APIKey` 제거 (빈 문자열) |
| 죽은 코드 | `NSPlayerView.swift` | 미사용 `playerLayer` 변수 제거 |
| 영상 재생 지연 | `PlayerView.swift` | `setupPlayer()`에서 ffprobe/트랜스코딩을 Task로 비동기 분리 |

## 14. 알려진 이슈

- `estimateSubtitles`에서 `chunkSize` 변수 사용 안 함 (warning, 무해)

---

## 15. DebugPanel v1.7 (전체 기능표)

> **핵심 원칙**: 
> 1. 메뉴바 우선 — LSUIElement 앱이지만 `NSEvent.addLocalMonitor`로 `Cmd+D` 전역 처리
> 2. NSWindow 1회 생성 후 재사용, `.floating + 100`, 화면 중앙 600×320
> 3. 자동 스크롤 📌 토글, 드래그 시 2초 일시정지
> 4. NSTextView 금지 — 순수 SwiftUI Text
> 5. release에서는 `#if DEBUG` + Package.swift `.define("DEBUG")`로 제거

### 메뉴바 처리 (LSUIElement 우회)

`LSUIElement = true` 앱이므로 `NSApp.mainMenu`가 SwiftUI에 덮어씌워짐.
→ `AppDelegate`의 `NSEvent.addLocalMonitorForEvents`에서 `keyCode == 2` (D)로 `openDebugLogWindow()` 직접 호출

```
Debug 메뉴 (메뉴바에 표시 안 됨, 단축키만 동작):
  Show/Hide Debug Panel    Cmd+D        → openDebugLogWindow()
  Copy Selection           Cmd+Shift+C  → copySelection()
  Copy All for Agent       Cmd+Shift+A  → copyAll()
  Clear Logs               Cmd+K        → clear()
  Auto Scroll (📌)         Cmd+Shift+S  → toggleAutoScroll()
```

### 로그 포맷

```
[HH:mm:ss.SSS] [LEVEL] [MACOS] [CATEGORY] msg | meta={json}
```

| 레벨 | 색상 |
|------|------|
| `ACTION` | white |
| `API→` | #74C0FC (blue) |
| `API←` | #8CE99A (green) |
| `INFO` | gray |
| `PERF` | #8CBF73 (green) — 성능 로그 (예: 플레이어 첫 프레임) |
| `CACHE` | #D9B038 (gold) — AI 캐시 히트 (cost_saved 포함) |
| `WARN` | #FFD43B (yellow) |
| `ERROR` | #FF6B6B (red) |
| `SYSTEM` | #CC5DE8 (purple) |

### 전체 기능표

| 기능 | 사양 | 코드 위치 |
|------|------|-----------|
| 로그 레벨 | 9종 고정 (ACTION/API→/API←/INFO/PERF/CACHE/WARN/ERROR/SYSTEM) | `DebugLogLevel` enum |
| 최대 로그 수 | 5000, FIFO | `DebugLogger.maxLogs` |
| release 차단 | `#if DEBUG` + `.define("DEBUG", .when(configuration: .debug))` | `Package.swift` |
| 포맷 | `[HH:mm:ss.SSS] [LEVEL] [PLATFORM] [CATEGORY] msg \| meta={json}` | `push()` |
| 토글 | `Cmd+D` (메뉴바 → `NSEvent` 모니터) | `AppDelegate` key monitor |
| Window 위치 | 화면 중앙 600×320, 최소 400×200, 최대 2000×1200 | `openDebugLogWindow()` |
| 최상위 레벨 | `.floating + 100` | `NSWindow.level` |
| 앱 활성화 | `NSApp.activate(ignoringOtherApps: true)` | `show()` |
| 자동 스크롤 | 📌 버튼 토글, 드래그 시 2초 일시정지 | `DebugLogView` |
| 줄 선택 | 클릭=1줄, Shift+클릭=범위, Cmd+클릭=개별 | `handleTap()` |
| 선택 복사 | 선택 줄만 → 클립보드 | `copySelection()` |
| 전체 복사 | 전체 로그 → 클립보드 | `copyAll()` |
| 클리어 | 확인 없이 제거 | `clear()` |
| 색상 | ERROR=red, WARN=yellow, API→=blue, API←=green, SYSTEM=purple | `textColor()` |
| print() 동시 출력 | `push()` → `print()` + `os_log` | `push()` |
| popover 회피 | `toggle()` 시 `performClose(nil)` 우선 | `toggle()` |
| Window 재사용 | 1회 생성, `orderOut`/`makeKeyAndOrderFront` | `NSWindow` |
| isReleasedWhenClosed | `false` | `NSWindow` config |
| NSTextView 금지 | SwiftUI `Text` + `ScrollViewReader` + `Set` selection | `DebugLogView` |

### 구현 시 주의사항

1. **Window 재사용 + isReleasedWhenClosed=false** — 두 번째 열 때 검은 화면 방지
2. **popover 회피** — LSUIElement 앱에서 popover 뒤에 숨는 버그 방지
3. **자동 스크롤 2초 일시정지** — `DispatchWorkItem`, Timer 사용 금지
4. **NSTextView 금지** — SwiftUI `Text`가 5000줄에서 30% 빠름
5. **배경은 항상 검정(opacity 0.92)** — 라이트 모드 가독성
6. **meta 500자 제한** — Xcode 콘솔 freeze 방지
7. **메뉴바 우선** — `NSEvent.addLocalMonitor`는 `LSUIElement` 앱에서도 동작함

### 참고 구현 파일

| 파일 | 역할 |
|------|------|
| `Sources/.../Debug/DebugLogManager.swift` | `DebugLogEntry` + `push()` / `clear()` / `formatForAgent()` |
| `Sources/.../Debug/DebugLogView.swift` | `DebugLogView` (로그 목록) + `DebugLogWindowView` (NSWindow) |
| `Sources/.../App/AppDelegate.swift` | `openDebugLogWindow()` + `Cmd+D` 키 모니터 |

### Window 설정 (필수 유지)

```swift
let win = NSWindow(
  contentRect: NSRect(x: 0, y: 0, width: 600, height: 320),
  styleMask: [.titled, .closable, .resizable, .miniaturizable],
  backing: .buffered, defer: false
)
win.center()
win.minSize = NSSize(width: 400, height: 200)
win.maxSize = NSSize(width: 2000, height: 1200)
win.level = .floating + 100
win.isReleasedWhenClosed = false
win.isMovableByWindowBackground = true
win.title = "🐛 Debug Logs"
```

## 16. AI 모델 정책 (docs/AI_MODELS.json)

- **유일 권위**: `docs/AI_MODELS.json` — 기본 체인 `openrouter/free → yTeaser/ax4 → gemini`
- 캐시: SQLite `video_ai_data` (요약/자막/태그), `summary_v2.5` 이상
- 히트 시 `[CACHE]` 로그 + `meta.cost_saved`

## 17. 에러코드 체계 (E-MAC-)

- 형식: `E-MAC-{CATEGORY}-{NUM4}` (개인 macOS 전용, `COM` 미사용)
- 범례: `error_message_ko.json`에 한국어 메시지 매핑 (참조 스펙 — 런타임 코드는 `n-XXXX` throw 유지)
- 카테고리: `API`, `NET` 등 (공통 권장 카테고리에 `API` 포함 사용)

## 18. v2.8.1 개인 규칙 적용 (v2.1 공통 규칙 macOS 적용분)

- **문서 우선**: 코딩 전 `docs/plans/PLAN_v{version}_macos.md` → `docs/TODO.md`(T-번호) 순서
- **세션 로그**: 작업 종료 시 `/.agent/session-YYYY-MM-DD-macos.md` 8줄 요약 저장 (15분마다 중간 저장)
- **시크릿**: `scripts/env-expiry-check.sh` — `.env` 등 `# expires:` 파싱, 30일 전 WARN/만료 시 ERROR
- **텍스트 검증**: `scripts/a11y-dump.sh [VERSION]` → `docs/screenshots/macos/` .a11y.txt + .storage.json + .perf.json
- **PERF/CACHE**: DebugLogger 9종 레벨, 플레이어 첫 프레임은 `.PERF`, 요약 캐시 히트는 `.CACHE`
- **개인 편의 최우선**: 위 공통 규칙도 개인 프로젝트 원칙(장 0)을 우선으로 해석

## 19. 디자인 시스템 (v3.2, T-1080~T-1083)

- **권위**: `docs/DESIGN_SYSTEM.md` — 4계층 구조(L1 토큰 → L4 화면 적용)
- **L1 토큰**: `Sources/TubeKeep/Theme/DesignTokens.swift` — `AppColors`/`AppFont`/`AppMetrics`
- **L2·L3 컴포넌트**: `Sources/TubeKeep/Components/` — AppSearchField, StatusBadge, EmptyStateView,
  AppPrimaryButton, ErrorBanner, SectionHeader, LibrarySortBar, SelectionBar
- **필수 규칙**:
  - 작업 단계에서 `.blue/.orange/.green/.red` 직접 사용 금지 → `AppColors` 경유
  - 셀/배지/헤더 폰트는 `AppFont` 경유
  - 정렬 바/선택 바/빈 상태/배지/검색 필드는 컴포넌트로 재사용 (중복 금지)
  - 포인트 색은 시스템 블루(`Color.accentColor`) 유지
  - `AppPrimaryButton` 등은 ButtonStyle 미채택 → 기존 스타일 지정과 충돌 없음
- **검증**: 변경 후 `swift build -c debug` → `swift test`(76개) → `./scripts/test-core.sh`(23 PASS)

## 20. 버전 정보

- **현재 버전**: v2.8.1 (working) — 그 외 릴리즈: v2.7.7 (build 18)
- **CFBundleShortVersionString**: 2.7.7
