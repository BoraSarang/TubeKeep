# AGENTS.local.md — TubeKeep 프로젝트 특화 가이드

> 이 파일은 공통 `AGENTS.md`를 확장한다.
> TubeKeep 프로젝트에서만 적용되는 규칙을 정의한다.
> 공통 규칙과 충돌 시 이 파일이 우선한다.

**프로젝트명**: TubeKeep (YouTube 다운로더 + 라이브러리 + AI 요약)
**기술 스택**: SwiftUI, TCA (The Composable Architecture), SwiftData, SQLite, yt-dlp
**번들**: `LSUIElement = true` (메뉴바 에이전트 앱)

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
| `BRAND.md` | 앱 이름, 슬로건, 브랜드 무드 |
| `UI_DESIGN.md` | 사이드바 네비게이션, Discover 탭, AI 요약 UI |
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
│   ├── PLAN_v2.5.2.md
│   ├── PLAN_v2.5.3.md
│   └── archive/          # 완료된 버전 보관
├── tests/
│   ├── v2.3.0.md         # ✅ 완료
│   ├── v2.5.0.md         # 진행 중
│   └── v2.5.x.md
```

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

## 8. 버전 정보

- **현재 버전**: v2.7.7 (build 18)
- **CFBundleShortVersionString**: 2.7.7

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
| `WARN` | #FFD43B (yellow) |
| `ERROR` | #FF6B6B (red) |
| `SYSTEM` | #CC5DE8 (purple) |

### 전체 기능표

| 기능 | 사양 | 코드 위치 |
|------|------|-----------|
| 로그 레벨 | 7종 고정 | `DebugLogLevel` enum |
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
