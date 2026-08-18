# PLAN v4.0 — macOS UI/UX 전면 개편 (맥 앱답게)

## 개요
- TubeKeep의 모든 창·화면·디버그 패널을 macOS 표준 디자인 어휘로 전면 개편
- 목표: "대충 봐도 아, 맥 앱이구나" 느낌 — iOS 감성(라운드 카드, 스위치 토글, 풀컬러 선택, 오버레이 컨트롤) 제거 + 시스템 Scene/material/토큰 도입
- 스킬 적용: `macos-app-design` + `ios-the-final-5-percent` + `apple-design`(emilkowalski)
- 라이트/다크 **양쪽 모두 대응** (semantic 색/material 기반)

## 사전 조사 요약 (2026-08-18, READ-ONLY)
| 진단 | 근거 |
|------|------|
| SwiftUI Scene 비어 있음 — 창 9개를 AppDelegate가 수동 NSWindow 생성 | `TubeKeepApp.swift:8-9`, `AppDelegate.swift:355-624` |
| iOS 스타일 선택 배경 (accentColor 풀블록 + 흰 글자) | `SidebarSelectableRow.swift:63`, `ChannelListView.swift:340` |
| 리스트가 전부 커스텀 (ScrollView+LazyVStack, List(.sidebar)/Table 0건) | `LibraryListView.swift:83`, `LibrarySidebarView.swift:588` |
| 하드코딩 색 96건 + `Font.system(size:)` 410건 — DesignTokens 사실상 무력화 | `DesignTokens.swift:26-31`, `DebugLogView.swift:156` |
| Material 거의 미사용 — 대부분 `Color(.windowBackgroundColor)` 플랫 | 전 화면 |
| 툴바에 xmark/power/pin 수동 버튼 6개 파일 반복 | `MainView.swift:99-133`, `VideoDownloadView.swift:29-45` |
| 설정 창 리사이즈 불가 + 140px 커스텀 탭 | `AppDelegate.swift:526-534`, `SettingsView.swift:10-31` |
| toggleStyle(.switch) 23곳 — macOS 표준은 체크박스/기본 토글 | `SettingsAITab.swift:39`, `BatchDownloadView.swift:93` |
| 고정 창 크기 (보관함 840, 플레이어 854+320, 다운로더 520) | `FixedWidthWindowController.swift:12-14`, `PlayerView.swift:22-23` |
| 플레이어 iOS 오버레이 컨트롤 (hover 3초 숨김) | `PlayerView.swift:443-521` |
| 디버그 패널 검은 터미널 스타일 커스텀 NSWindow(.floating+100) | `DebugLogView.swift:126`, `AppDelegate.swift:640-651` |

## 결정 사항
1. **설정만 Scene화 먼저** (리스크 낮고 파급 큰 Settings Scene) — 나머지 창은 우선 스타일링
2. **라이트/다크 양쪽 대응** — semantic 색 + material, 다크 하드코딩 전면 제거
3. **P1 테마 토큰부터** — 색/폰트/재질 토큰 정비 후 화면 일괄 적용
4. 이후 P2 설정 Scene화 → P3 사이드바/리스트 표준화 → P4 화면별 적용 → P5 플레이어+디버그 패널

## 구현 단계 (T-번호)

### P1 — 테마 토큰 전면 재작성 (T-1151~T-1155)
| 작업 | 파일 | 내용 |
|------|------|------|
| T-1152 | `Theme/DesignTokens.swift` | RGB 하드코딩 4곳 제거 → **Display P3** 브랜드 + semantic 색(`selectedContent`, `secondaryLabel`, `separator`, material 계열) + progressTrack 등 다크 가정 제거(`primary.opacity`) |
| T-1153 | `Theme/DesignTokens.swift` | `AppFont` → 시스템 상대 스타일(.callout/.caption/.caption2) 기반 재정의 (Dynamic Type 연동) |
| T-1154 | Components 5종 + SidebarSelectableRow | `AppSearchField`(네이티브 필드), `ErrorBanner`/`StatusBadge`(semantic), `SidebarSelectableRow`(selectedContent + hover), `LibrarySortBar`/`SelectionBar`(토큰 적용) |
| T-1155 | 빌드+검증+문서 | `./build_and_run.sh debug macos` 성공 → DebugPanel → CHANGELOG/TODO 마감 |

### P2 — 설정 창 Scene화
| 작업 | 파일 | 내용 |
|------|------|------|
| T-1156 | `App/TubeKeepApp.swift` | `Settings { SettingsView(...) }` Scene 추가 |
| T-1157 | `App/AppDelegate.swift` | `openSettingsWindow()` 설정 창 생성부 제거 + `openWhisperSettings()` 대응 (523-541) |
| T-1158 | `Features/Settings/SettingsView.swift` | 140px 사이드바+switch → 상단 TabView, `selectedTab` store 상태 연결 유지 |
| T-1159 | 상태바/메뉴바 설정 항목 | `StatusBarManager`, `AppDelegate:248,318` → 표준 설정 경로 연결 |

### P3 — 사이드바/리스트 표준화
| 작업 | 파일 | 내용 |
|------|------|------|
| T-1160 | `Library/MainView.swift` | HStack+switch → `NavigationSplitView` + `List(selection:)` `.listStyle(.sidebar)` |
| T-1161 | `Library/LibrarySidebarView.swift` | 커스텀 행 → sidebar 리스트, 선택/hover/행 높이 표준화, 드래그 재정렬 유지 |
| T-1162 | `Library/LibraryListView.swift` | 커스텀 카드 행 → 표준 List(썸네일 120x68), 좌클릭 NSMenu → contextMenu |
| T-1163 | `FixedWidthWindowController.swift` + `MainView` 툴바 | 보관함 840 고정 폭 제거 + 툴바 xmark/power/pin 제거 |

### P4 — 화면별 적용
| 작업 | 파일 | 내용 |
|------|------|------|
| T-1164 | Home/DownloadQueue/Channel/Discover/History/Trash/Profile/AI | P1 토큰 일괄 적용 + 창 고정 크기 해제(downloader 520, channel 720, batch 480 zoom 복구) |
| T-1165 | 설정 탭 8종 | toggleStyle(.switch)→기본 Toggle, controlSize(.mini) 제거, SecureField 네이티브 |

### P5 — 플레이어 + 디버그 패널
| 작업 | 파일 | 내용 |
|------|------|------|
| T-1166 | `Player/PlayerView.swift` | iOS 오버레이 컨트롤 → 상시 컨트롤바, 창 폭 자동 계산 제거(minWidth 기반) |
| T-1167 | `Debug/DebugLogView.swift` | 검은 터미널 → macOS 콘솔 스타일(regularMaterial + semantic + SF Mono 11pt), floating 레벨 재검토 |

## 검증 계획
- TC-001: P1 후 빌드 성공 + DebugPanel(⌘D) 정상 + 라이트/다크 전환 시 색 자연
- TC-002: P2 후 ⌘, → 시스템 설정 창 + 탭 전환 동작 + 리사이즈 가능
- TC-003: P3 후 사이드바 드래그 리사이즈 + 선택/hover + 키보드 네비게이션
- TC-004: P4/P5 후 전 창 화면 회귀 없음 + 다운로드/재생 정상
- 검증 도구: `./build_and_run.sh debug macos` + a11y-dump(텍스트 전용) + 스크린샷

## 롤백
- 단계별 커밋 분리 → 문제 발생 시 해당 커밋 `git revert`
- Scene 전환(P2)이 회귀를 일으키면 `openSettingsWindow()` 코드 복원으로 즉시 롤백
- 토큰 변경(P1)은 시각적 변화만 — 기능 로직 영향 없음

## 리스크
- P2 Scene 전환 시 `selectedTab`/`editingPreset` 상태 연결 유지 필요
- P3 리스트 표준화 시 드래그 재정렬/좌클릭 메뉴 등 커스텀 인터랙션 유실 우려 — contextMenu로 대체
- 하드코딩 96건/410건 전면 치환은 회귀 위험 — P1~P5 단계별로 점진 적용