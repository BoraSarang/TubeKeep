# PLAN v4.2 — 단축키 체계 정리 + fullscreen 크래시 수정 (macOS, T-1172~T-1178)

## 개요
- fullscreen 진입/종료 중 크래시 (glBlitFramebuffer nil window) 수정
- 스페이스바 토글이 "안 먹는" 문제 근본 해결 (PlayerView 잔존 다중 인스턴스)
- Cmd+D 3중 정의 → local monitor 1곳 단일화, Cmd+W 신규, 메뉴바 실행 직후 소멸 방지, Dock 클릭 복구

## 결정 사항
1. fullscreen: `renderFrame`/`updateGLContext`에 `window.screen != nil` 가드 + `isFullscreenTransition` 락
2. 스페이스: PlayerWindow이 `object: self`로 post, PlayerView는 자기 창과 일치할 때만 토글
3. Cmd+D: KeyCommandHandler(local monitor)만 처리, AppDelegate·StatusBarManager의 keyEquivalent "d" 제거
4. Cmd+W: KeyCommandHandler case 6 — `keyWindow?.performClose(nil)` 직접 호출
5. 메뉴바: 실행 0.3초 후 `setupMainMenu()` 재호출 (SwiftUI 기본 메뉴 덮어쓰기 방지)
6. 텍스트 가드: 스페이스/화살표만 텍스트 입력 중 통과, cmd 조합은 항상 처리
7. Dock: `applicationShouldHandleReopen` 추가

## 변경 범위
| 파일 | 변경 |
|------|------|
| `Sources/TubeKeep/Features/Player/MPVClient.swift` | renderFrame 가드 + fullscreen observers + transitionLock |
| `Sources/TubeKeep/Features/Player/MPVVideoView.swift` | updateGLContext screen nil 가드 |
| `Sources/TubeKeep/Features/Player/PlayerView.swift` | 토글 조건 제거 + post 창 비교 가드 |
| `Sources/TubeKeep/App/PlayerWindow.swift` | post 시 object: self |
| `Sources/TubeKeep/App/KeyCommandHandler.swift` | case 2 복원 + case 6(w) 신규 + 텍스트 가드 재구성 |
| `Sources/TubeKeep/App/AppDelegate.swift` | 파일 메뉴(Cmd+W) + applicationShouldHandleReopen + setupMainMenu 지연 재호출 + Debug 메뉴 "d" 제거 |
| `Sources/TubeKeep/App/StatusBarManager.swift` | 상태바 Debug 메뉴 "d" 제거 |

## 구현 단계 (완료)
- T-1172: fullscreen 크래시 가드 + observers
- T-1173: 스페이스 post 창 비교 (object: self)
- T-1174: Cmd+D 단일화 (KeyCommandHandler 복원 + 메뉴 "d" 제거)
- T-1175: Cmd+W (파일 메뉴 + local monitor case 6)
- T-1176: 메뉴바 소멸 방지 (asyncAfter 재호출)
- T-1177: 텍스트 가드 재구성
- T-1178: Dock 클릭 복구 (applicationShouldHandleReopen)

## 검증 (완료)
- 빌드 성공 (DebugPanel ON) + 메뉴바 "Apple, 튜브킵, 파일, 편집, 다운로더, Debug" 확인
- 사용자 검증: Cmd+D 1회 토글, 스페이스 토글 정상, fullscreen 크래시 없음
- 전체 복사 로그: 사용자 제공 로그에서 `[PlayerView] toggle received` 1회로 수렴

## 롤백
- git revert + 재빌드 (build_and_run.sh debug macos)