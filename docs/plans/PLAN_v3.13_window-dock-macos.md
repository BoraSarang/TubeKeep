# PLAN v3.13 — Dock 표시 + 메인창→보관함 용어 통일 + 단축키 별도 탭 (macOS)

## 개요
v3.12(랜딩 리디자인, 앱 코드 무변경) 완료 후 사용자가 요청한 macOS 창 관련 개선 3종.

1. **Dock 표시**: 현재 앱은 `Info.plist`의 `LSUIElement = true`로 **메뉴바 전용(accessory)** 모드라 Dock 아이콘이 없다. 사용자가 "메뉴바 앱이 아니라 Dock도 사용하는 것으로 아는데?"라고 문의. **하이브리드(메뉴바 아이콘 유지 + Dock 아이콘 추가)** 로 전환하고, 보관함/플레이어/다운로더 3종 창이 Dock에서 최소화 축소판으로 접근 가능하게 한다.
2. **용어 통일**: 설정의 "메인창 자동 표시"가 앱 전반의 "보관함" 용어와 어긋난다. UI 라벨과 내부 식별자를 모두 "보관함(library)"으로 통일한다.
3. **단축키 별도 탭**: "일반" 탭(`SettingsSystemTab`) 하단의 전역 단축키 섹션을 별도 "단축키" 탭으로 분리한다.

**원칙**: 한국어 문서 우선, 1커밋 1관심사(A: Dock / B: 용어 / C: 단축키), 빌드·실행 검증 후 커밋.

## 결정 사항
- **Dock 방식**: `Info.plist` `LSUIElement: true → false` (런타임 `setActivationPolicy` 대신 정석) → Dock 아이콘 + Cmd+Tab 노출. 메뉴바 아이콘은 `StatusBarManager` 코드로 계속 생성(하이브리드).
- **최소화 가능**: 영상 다운로더(`downloader`), 일괄 다운로더(`batch`) styleMask에 `.miniaturizable` 추가. 보관함(`lib`)·플레이어(`player`)·채널(`channel`)은 이미 보유. 설정·AI·정보 창은 고정 크기라 대상 제외.
- **용어**: `openMainWindow`→`openLibraryWindow`, `showMainWindowOnLaunch`→`showLibraryOnLaunch`, `toggleShowMainWindowOnLaunch`→`toggleShowLibraryOnLaunch`, `openMainWindowNotification`→`openLibraryWindowNotification`, `showMainWindowOnLaunchKey`→`showLibraryOnLaunchKey`.
  - 무관 항목 제외: `setupMainMenu`/`refreshMainMenu`(앱 메뉴바), `runOnMain`(Main 스레드), `DispatchQueue.main`/`MainActor`.
  - **UserDefaults 마이그레이션**: Settings는 JSON을 `appSettings` 키에 통째 저장. CodingKey rawValue 변경 시 기존 저장 JSON의 `showMainWindowOnLaunch` 필드가 새 키(`showLibraryOnLaunch`)와 불일치 → decode 폴백(이전 키 먼저)으로 기존 설정값 보존.
  - **부수 정리**: AppDelegate L195-198의 빈 `if` 블록 잔재(`if !showLibraryOnLaunch {} else { openLibraryWindow() }`)를 단순화.
- **단축키 탭**: `SettingsTab`에 `case shortcuts = "단축키"` 추가, 아이콘 `keyboard`, 사이드바 "일반" 앞에 배치. `SettingsShortcutsTab.swift` 신규 생성(기존 `globalShortcutsSection` + `GlobalShortcutRow` + `handleRecording` + 상태 이동).

## 아키텍처

### A. Dock 표시
- `Info.plist` `LSUIElement` 키: `true` → `false`
- `AppDelegate.openVideoDownloaderWindow()` styleMask: `[.titled, .closable, .resizable]` → `[.titled, .closable, .resizable, .miniaturizable]`
- `AppDelegate.openBatchDownloadWindow()` styleMask: 동일하게 `.miniaturizable` 추가
- `applicationShouldTerminateAfterLastWindowClosed` → `false` 유지 확인 (마지막 창 닫아도 메뉴바로 유지)

### B. 용어 통일 (메인창 → 보관함)
| 파일 | 변경 |
|------|------|
| `SettingsSystemTab.swift:91` | "메인창 자동 표시" → "보관함 자동 표시", "실행 시 메인 창을 자동으로 엽니다" → "실행 시 보관함을 자동으로 엽니다" |
| `AppDelegate.swift` | `openMainWindow()`→`openLibraryWindow()`, L195-198 if-else 단순화, `statusBar.onOpenMainWindow` 클로저 rename |
| `StatusBarManager.swift` | `onOpenMainWindow`/`openMainWindow` → `openLibraryWindow` 계열 |
| `Settings.swift` | `showMainWindowOnLaunch`→`showLibraryOnLaunch` + CodingKey 폴백(decode), SettingsTab은 C와 함께 수정 |
| `SettingsReducer.swift` | `showMainWindowOnLaunch`→`showLibraryOnLaunch`, `toggleShowMainWindowOnLaunch`→`toggleShowLibraryOnLaunch` |
| `AppReducer.swift` | L128-129 사용처 rename |
| `Constants.swift` | `openMainWindowNotification`→`openLibraryWindowNotification`(값 "com.tubekeep.openLibraryWindow"), `showMainWindowOnLaunchKey`→`showLibraryOnLaunchKey`(값 "showLibraryOnLaunch") |
| `BatchDownloadView.swift:456` | `Constants.openLibraryWindowNotification` 사용 |

### C. 단축키 별도 탭
- `Settings.swift` `SettingsTab`: `case shortcuts = "단축키"` + icon `keyboard` (general 앞)
- `SettingsShortcutsTab.swift` **신규**: `SettingsSystemTab`의 `globalShortcutsSection`·`GlobalShortcutRow`·`handleRecording`·`@State recording/keyMonitor/shortcutsVersion` 이동. `SettingsSystemTab`과 동일하게 `StoreOf<SettingsReducer>` 수신.
- `SettingsSystemTab.swift`: 전역 단축키 관련 코드 전체 제거(플레이어/앱 시작 섹션만 유지), `onChange(of: recording)`·`onDisappear`(키 모니터 정리) 제거
- `SettingsView.swift`: `switch`에 `case .shortcuts: SettingsShortcutsTab(store: store)` 추가
- `SettingsReducer.swift`: Action/State 변경 없음 (SettingsTab enum 확장만으로 충분, `setSelectedTab`은 SettingsTab 타입)

## 구현 단계 (T-번호)
| ID | 작업 | 상세 |
|----|------|------|
| T-1131 | **PLAN_v3.13 + TODO 등록** | docs/plans/PLAN_v3.13_window-dock-macos.md + docs/TODO.md v3.13 섹션 |
| T-1132 | **A. Dock 표시** | Info.plist LSUIElement false + AppDelegate 다운로더 2종 .miniaturizable |
| T-1133 | **B. 용어 통일** | 8개 파일 rename + Settings decode 폴백 + AppDelegate if-else 정리 |
| T-1134 | **C. 단축키 탭** | SettingsTab .shortcuts + SettingsShortcutsTab.swift + SettingsSystemTab 정리 + SettingsView switch |
| T-1135 | **빌드 + 실행 검증** | build_and_run.sh debug macos → Dock 아이콘/축소판, 단축키 탭, 보관함 자동 표시 토글·설정값 유지 |
| T-1136 | **문서 마감 + 커밋** | CHANGELOG v3.13 + TODO done + session 로그 + 커밋 (A/B/C 분리) |

## 테스트 계획
- 빌드: `./build_and_run.sh debug macos` (또는 `make build`) 성공
- 실행 검증 (수동):
  1. Dock 아이콘 표시 + Cmd+Tab에 노출 (메뉴바 아이콘 유지)
  2. 보관함/플레이어/영상·일괄·채널 다운로더 창 열기 → 최소화(노란 버튼) → Dock 축소판 생성
  3. 마지막 창 닫아도 앱 유지(메뉴바 아이콘 남음)
  4. 설정 "단축키" 탭 표시, 단축키 기록/해제 동작
  5. 설정 "일반" 탭에서 단축키 섹션 제거 확인
  6. "보관함 자동 표시" 토글 + 기존 저장값(false로 설정돼 있었을 때) 유지
- 스크린샷: `screencapture`로 Dock + 설정 탭 캡처 (텍스트 검증 병행)

## 롤백 계획
- A: `Info.plist` `LSUIElement` 되돌리기 + styleMask 복원
- B: `git revert` 해당 커밋 (저장값은 폴백으로 인해 손실 없음)
- C: `SettingsTab` 케이스 제거 + SettingsSystemTab 복원
- 전체: `git revert` + `build_and_run.sh debug macos` 재빌드