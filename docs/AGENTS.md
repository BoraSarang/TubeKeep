# AGENTS.md — AI 에이전트 작업 가이드

**제작자**: BoRaSaRang · **EMail**: borasarang@gmail.com

이 프로젝트는 AI 에이전트가 코드를 이해하고 수정할 수 있도록 5개의 문서 파일로 관리됩니다.
아래 규칙을 따라 각 파일을 유지보수하세요.

---

## 문서 파일 목록

| 파일 | 목적 | 포함 내용 |
|------|------|-----------|
| `PRD.md` | 제품 요구사항 정의 | 사용자 스토리, 기능 명세, 제약 조건 |
| `DESIGN.md` | 기술 설계 문서 | 아키텍처, 데이터 흐름, 컴포넌트 설계, 코드 구조 |
| `PLAN.md` | 구현 일정/계획 | 완료된 작업, 진행 중 작업, 향후 계획 |
| `TODO.md` | 작업 추적 목록 | 세부 할 일 목록 (상태: pending/in_progress/completed/cancelled) |
| `AGENTS.md` | AI 에이전트 가이드 | 파일 설명, 업데이트 규칙, 작업 지침 |
| `BRAND.md` | 브랜드 아이덴티티 | 앱 이름, 슬로건, 브랜드 가치, 무드 |

---

## 파일 관리 규칙

### 1. 변경 사항이 생기면 반드시 관련 파일을 업데이트하라

- **코드 구조 변경** (새 파일 추가, 리팩토링) → `DESIGN.md` 업데이트
- **기능 추가/변경** (새 UI, 새 동작) → `PRD.md` + `DESIGN.md` 업데이트
- **작업 완료/진행 상황 변경** → `PLAN.md` + `TODO.md` 업데이트
- **에이전트 관련 규칙 변경** → `AGENTS.md` 업데이트

### 2. 업데이트 타이밍

- **즉시 업데이트**: 기능 구현 완료 시, 리팩토링 완료 시
- **함께 업데이트**: 코드 수정과 문서 수정은 같은 작업 단위로
- **누락 금지**: 문서 업데이트 없이 코드만 수정하지 말 것

### 3. 각 파일의 역할과 작성 지침

#### PRD.md
- 제품의 `무엇`을 정의 (기술적 구현 제외)
- 사용자 관점의 기능 설명
- 우선순위와 제약 조건

#### DESIGN.md
- 제품의 `어떻게`를 정의
- 구체적인 기술 설계: 아키텍처, 컴포넌트, 데이터 흐름
- 코드 구조와 파일 매핑
- TCA Reducer 구조, State/Action 정의

#### PLAN.md
- 작업의 `언제/무엇을` 정의
- 완료된 기능 목록
- 진행 중인 작업 (in_progress)
- 향후 계획 (pending)
- 마일스톤

#### TODO.md
- 개별 작업 단위 추적
- 각 작업: 설명 + 상태(pending/in_progress/completed/cancelled)
- 작업 우선순위 (high/medium/low)
- 작업 완료 조건

---

## 작업 시작 전 확인사항

1. `AGENTS.md` 읽기 — 작업 규칙 숙지
2. `PRD.md` 읽기 — 제품 요구사항 이해
3. `DESIGN.md` 읽기 — 기존 설계 이해
4. `PLAN.md` 읽기 — 현재 진행 상황 확인
5. `TODO.md` 읽기 — 구체적인 작업 목록 확인

## 작업 완료 후 확인사항

1. 변경된 코드가 문서와 일치하는가?
2. `PRD.md`에 반영되지 않은 새 기능이 있는가?
3. `DESIGN.md`에 반영되지 않은 설계 변경이 있는가?
4. `PLAN.md`의 진행 상태가 최신인가?
5. `TODO.md`의 작업 상태가 최신인가?

---

## 공동 작업 규칙

- 한 번에 하나의 작업만 `in_progress`로 설정
- 작업이 완료되면 `completed`로 표시하고 관련 파일 업데이트
- 작업이 막히면 `in_progress` 유지 + `TODO.md`에 블로커 명시
- 다른 에이전트가 작업 중인 파일을 수정하지 말 것
- 에이전트와의 모든 대화는 **한국어**로 진행한다

### 질문-응답-수정 워크플로

사용자가 "~할 수 있나?", "~는 안 되나?" 등 의문문으로 질문하면:

1. **즉시 코드 수정하지 말 것** — 먼저 가능 여부, 접근법, 장단점, 영향 범위를 설명
2. 사용자가 "그렇게 해" / "해줘" / "적용해" 등 명확한 승인을 한 후에만 코드 수정
3. 코드 수정 후에는 별도 설명 없이 결과만 간략히 전달
4. 같은 주제로 반복 질문-응답 사이클을 돌지 말 것 — 첫 응답에 모든 옵션과 판단 근거를 종합적으로 제시

### 플랜 모드 vs 빌드 모드

**핵심 규칙**: 사용자가 빌드/수정/실행을 명시적으로 지시할 때만 파일을 수정한다.

| 모드 | 조건 | 파일 쓰기 허용? |
|------|------|----------------|
| **플랜 모드** (기본) | 사용자가 의견/질문/아이디어만 말함 | ❌ 절대 금지 |
| **빌드 모드** | 사용자가 "빌드해", "수정해", "재 실행해", "진행해", "해줘", "적용해" 등 실행 명령을 말함 | ✅ 허용 |

- 플랜 모드에서는 **어떤 파일도 생성하거나 수정하지 말 것** (코드, 문서, 설정 파일 모두 포함)
- 사용자가 한마디 할 때마다 코드를 수정하지 말 것 — 하나의 작업을 여러 번 수정하지 않도록
- 빌드 모드로 전환되기 전까지는 분석/설명/제안만 할 것

## 빌드 & 실행 규칙

- 일반 빌드: `bash build_and_run.sh debug` — 빠른增量 빌드
- 클린 빌드 필요 시: `bash build_and_run.sh debug --clean` — `swift package clean` 실행
- 사용자가 "빌드해" / "재실행해" → 일반 빌드 (`--clean` 없이)
- 사용자가 "클린빌드" / "클린 빌드" → `--clean` 옵션 추가
- 절대 빌드 없이 기존 바이너리만 재실행하지 말 것

## 문제 해결 원칙

### 1. 최종 목표를 먼저 정의하라
- "이게 안 된다"가 아니라 "이걸 이루려면 어떤 방법들이 있는가"를 먼저 생각
- 실행 불가능한 이유를 나열하지 말고, 가능한 모든 접근법을 제시
- 각 접근법의 장단점을 설명하고 추천안을 제시한 후 사용자에게 선택권을 줘라

### 2. 외부 의존성은 번들에 포함하라
- yt-dlp, ffmpeg 등 외부 바이너리는 사용자 PATH에 의존하지 말고 `.app/Contents/Resources`에 포함
- 사용자가 "설치하라"는 메시지를 보게 하지 말 것
- 의존성 문제는 구현 전에 미리 파악하여 설계 단계에서 해결할 것

### 3. 근본 원인을 해결하라 (우회 금지)
- `--merge-output-format` 같은 부분 해결책으로 때우지 말 것
- "mp4가 안 나오면 번들에 ffmpeg 포함 + remux-video" 같은 근본 해결을 해라
- 경고 메시지(ffmpeg missing 등)는 즉시 캐치하고 근본적으로 해결해야 할 문제로 간주

### 4. 하나의 답만 제시하지 말고 여러 방법을 제시하라
- 문제 해결 시 최소 2~3가지 접근법을 검토
- 각 방법의 장단점, 난이도, 영향 범위를 함께 전달
- 사용자가 선택할 수 있도록 "방안 A, B, C" 형태로 제시

### 5. 사용자의 최종 경험을 기준으로 판단하라
- "사용자가 앱을 설치하고 나서 첫 실행 때 어떤 경험을 하는가?"
- 중간 과정(설치, 설정, 의존성)은 사용자에게 보이지 않게 해라
- 기능 하나를 추가할 때마다 "이게 사용자 입장에서 매끄러운가?"를 자문

## 공통 이슈 & 해결 기록

### 클립보드 감시 — 라이브러리 창 열려 있을 때
- `AppDelegate.swift` 라인 468: `mainVisible` 체크 후 다운로더 창을 열고 `autoFetchInfo` 전송
- 라이브러리 창 닫힘 → NSPanel 팝오버
- 라이브러리 창 열림 → 다운로더 창 오픈 후 autoFetch (수정 완료)

### 라이브러리 데이터 저장 race condition
- `AppReducer.downloadCompleted`에서 `addItem` + `loadFromDisk`를 순차적으로 실행
- UserDefaults는 atomic하지만 TCA effect는 비동기 → 순차 보장 필요

### FixedWidthWindowController dealloc 문제
- 반드시 `AppDelegate`의 프로퍼티(`mainWindowController`)에 저장할 것
- 로컬 변수(`let _ =`)에 할당하면 delegate 해제되어 width 고정失效

---

### 6. v1.1.0 전체 완료 (10건, 2026-07-14)

**v1.1.0 Medium 5건:**
- T-118: `LibrarySidebarView` — 채널 목록 하단 `+ 채널 추가` 버튼
- T-117: `LibrarySidebarView` — 채널 ForEach `.onMove` + UserDefaults `channelOrder`
- T-116: `LibraryReducer` — `downloadSubtitles`/`subtitleResult` 액션; Grid/List 좌클릭 메뉴 "자막 다운로드"
- T-111: `LibraryGridCell` — `onHover` + `.popover` 360×203 확대 미리보기
- T-112: `LibraryReducer` — `selectedIds` + selection actions; `LeftClickMenu` Cmd+클릭 토글; selectionBar

**v1.1.0 High 5건:**
- T-110: `LibrarySidebarView` — 하단 `출력 폴더 열기` 버튼 (store.settings.outputDirectory → NSWorkspace)
- T-113: `Info.plist` — `CFBundleURLTypes` → `tubekeep://` scheme; `AppDelegate.handleGetURLEvent` + `HomeReducer.setURL`
- T-119: `LibraryItem.uploadDate: Date?` 추가; `LibrarySortOrder`에 `uploadDateDesc`/`uploadDateAsc`; 채널 선택 시 기본 정렬=uploadDate; `parseUploadDate()`; Grid/List UI 날짜 표시 개선
- T-115: `DownloadQueueReducer` — `loadQueue`/`saveQueue`/`itemsLoaded` 액션; UserDefaults `downloadQueue` 키; 재시작 시 downloading/paused → pending 리셋
- T-114: `AppDelegate.startChannelUpdateCheck` (30분 타이머) → `ChannelFetchService.fetchAllVideos` → `ChannelDownloadCache.loadDownloadedIDs` + `loadSeenVideoIds`와 비교 → 새 영상 ID를 `channelsNewVideos`에 저장 + StatusBar badge (채널 수) + UNUserNotification
  - 뱃지 클릭 → 채널 다운로더 창 오픈 (첫 새 영상 채널 자동 선택), badgeReset
  - `channelsSeenVideoIds`: 사용자가 확인한 영상 ID 저장 (채널 선택/새로고침 시 `newIds→seenIds` 이동) → 다운로드 안 해도 재감지 안 됨
  - 다운로드 완료 시 `removeSeenVideoIds` 호출
  - 체크 진행률: 상태바 "업데이트 확인 중 (N/M) — 채널명" 표시 + DEBUG 로그(channelLogManager)
  - 채널 리스트 `ChannelRow`: 새 영상 채널에 빨간 ● 배지
  - `ChannelContentView.channelHeader`: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 배너
  - 채널 선택 시 `ChannelDownloadCache.saveSeenVideoIds` + `clearNewVideoIds` 호출

**새 상수:** `Constants.channelOrderKey`, `Constants.downloadQueueKey`

**새 서비스 메서드:** `LibraryCacheService.removeItems(ids:)`, `StatusBarReducer.setBadgeCount`

**변경 사항 요약:**
- **T-118**: `LibrarySidebarView` — 채널 목록 하단 `+ 채널 추가` 버튼 추가
- **T-117**: `LibrarySidebarView` — 채널 ForEach에 `.onMove` + UserDefaults `channelOrder` 키로 순서 저장
- **T-116**: `LibraryReducer` — `downloadSubtitles`/`subtitleResult` 액션 추가; `LibraryGridCell`/`LibraryListRow` — 좌클릭 메뉴에 "자막 다운로드" 추가
- **T-111**: `LibraryGridCell` — 썸네일에 `.onHover` + `.popover`로 360×203 확대 미리보기
- **T-112**: `LibraryReducer` — `selectedIds`, `toggleSelection`/`selectAll`/`clearSelection`/`removeSelected` 추가; `LeftClickMenu` — `onToggleSelection` closure, Cmd+클릭 시 토글; Grid/List — selectionBar (N개 선택됨 / 전체 선택 / 선택 해제 / 선택 삭제)

**새 상수:** `Constants.channelOrderKey`

**관련 서비스:** `LibraryCacheService.removeItems(ids:)` 추가

### 7. v1.2.0 — 채널 업데이트 알림 개선 + 디스크 사용량 (2026-07-16)

**T-114 보강:**
- `seenVideoIds` 도입: 채널 선택/새로고침 시 `newIds`를 `seenIds`로 이동 → 다운로드 안 해도 재감지 안 됨
- 상태바 진행률: "업데이트 확인 중 (N/M)" → `statusBar.updateStatusText` 액션 추가
- DEBUG 로그: `channelLogManager` → `libraryLogManager` (메인 TubeKeep 창에 표시)
- `openVideoDownloaderWindow`: `MainView` → `VideoDownloadView`로 수정
- StatusBar badge: 10초 autoReset 제거, 사용자 클릭 시까지 유지

**디스크 사용량:**
- `LibraryCacheService.calculateDiskUsage()` — `outputDirectory` + 캐시 디렉토리 FileManager.enumerator 합산
- `LibraryReducer`: `diskUsageBytes: Int64` State + `.calculateDiskUsage` / `.diskUsageUpdated` 액션
- AppReducer: downloadCompleted, removeSelected, removeItemsByChannel 후 `.library(.calculateDiskUsage)` 전송
- `LibrarySidebarView` 하단: `[폴더] Finder에서 보기  12.3 GB  ↻` — ↻ 버튼으로 수동 새로고침
- `formatBytes()` — `ByteCountFormatter` 포맷팅
- onAppear 시에도 1회 호출

**새 서비스 메서드:** `LibraryCacheService.calculateDiskUsage()` (static)

### 8. 반복 실수 방지 — 변경 전 3단계 검증
같은 유형의 실수가 반복되지 않도록 아래 규칙을 반드시 지킨다:

1. **기존 구현 확인**: 새 기능/수정을 하기 전에 반드시 동일한 기능의 기존 구현을 먼저 찾아서 읽는다
   - 예: 툴바 버튼 추가 시 `BatchDownloadView`의 툴바를 먼저 확인
2. **요청-수정 체크리스트**: 수정 완료 후 "사용자가 요청한 것"과 "내가 만든 것"을 항목별로 대조한다
   - 기능 A? ✅ / 기능 B? ❌ → 누락 발견 즉시 추가
3. **데이터로 검증, 추측 금지**: 원인 분석 시 "아마 ~일 것이다"로 끝내지 말고 실제 데이터/코드 경로를 추적해서 확인한다
   - 예: 타임아웃 원인을 "채널 영상이 많아서"라고 말하려면 먼저 실제 영상 수를 확인
   - 예: 권한 문제 원인을 "캐시 문제"라고 말하려면 먼저 어떤 파일 작업이 일어나는지 전부 추적
