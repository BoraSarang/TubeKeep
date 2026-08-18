# PLAN v4.1 — 플레이어 키 조작 + 반복 재생 (macOS)

## 개요
- 사용자 요청 3건 처리: ①플레이어 스페이스바 일시정지/해제 동작 안 함 수정, ②↑/↓ 화살표 볼륨 조절 추가, ③현재 영상 반복 재생 토글 추가
- 플레이어 UI/UX 변경 여부 질문 → **변경 없음**(v3.x 디자인 유지, git diff HEAD~1에서 Player 파일 2건은 로그 메시지 수정뿐) — 자동 숨김 컨트롤바는 기존 의도된 동작
- 스킬: 해당 없음(기능 로직 작업)

## 결정 사항
1. 스페이스바: `isPlayerKeyWindow` 판정을 "key window OR (visible && 앱 active)"로 완화 — 다른 창이 key여도 플레이어가 보이면 토글 (단, 보관함 검색 등 텍스트 입력 중에는 부작용 방지 위해 player window가 key가 아닐 때는 visible+active만으로 처리)
2. 볼륨: `KeyCommandHandler`에 keyCode 126(↑)/125(↓) → `onVolumeChange(delta)` 콜백 → NotificationCenter post → PlayerView onReceive로 `volume` 상태 + `mpv.setVolume` 동기화, 5단계 클램프 0...100
3. 반복: mpv `loop-file=inf` 프로퍼티 + controlBar에 반복 토글 버튼(repeat 아이콘, 활성 시 accentColor)

## 구현 단계 (T-번호)

| 작업 | 파일 | 내용 |
|------|------|------|
| T-1169 | `App/KeyCommandHandler.swift` + `App/AppDelegate.swift` | 스페이스바 토글 동작 수정 — `isPlayerKeyWindow` 완화, DEBUG 로그에 토글 결과 추가 |
| T-1170 | `App/KeyCommandHandler.swift` + `App/AppDelegate.swift` + `Helpers/Constants.swift` + `Features/Player/PlayerView.swift` | ↑/↓ 볼륨 조절 — 콜백 추가, `playerVolumeChangeNotification` 추가, PlayerView onReceive로 volume 동기화 |
| T-1171 | `Features/Player/MPVClient.swift` + `Features/Player/PlayerView.swift` | 영상 반복 — `setLoopFile(_:)` 추가, controlBar 반복 토글 버튼 + `@State isRepeatEnabled` |

## 검증 계획
- TC-001: 빌드 성공 (`./build_and_run.sh debug macos`)
- TC-002: DebugPanel 로그로 `[Key] Space`/`[Key] Volume` 확인
- TC-003: 플레이어 열어 스페이스바 토글 + ↑/↓ 볼륨 + 반복 버튼 동작 확인 (사용자 육안)

## 롤백
- 개별 커밋 단위 revert

## 리스크
- 스페이스바 판정 완화로 보관함 검색 필드 등에서 입력 중 스페이스바가 플레이어로 소비될 수 있음 — key window가 player가 아니면 visible+active 조건도 함께 검사하되, 텍스트 입력(first responder가 NSText)이면 이벤트 통과
