# PLAN v4.5 — 캐릭터 대화 기능 + macOS 네이티브 디자인 리빌딩 (macOS)

> 작성: 2026-08-20 · 플랫폼: macOS · 버전: v4.5
> 사용자 결정: ① 통합 계획 연속 진행 ② 네이티브 표준 전환(List(.sidebar)/Form(.grouped)) ③ macOS 15+ 타깃 상향 ④ 캐릭터 대화 기능 포함 ⑤ T-1183 다운로드 앱 검증은 사용자가 선행

---

## 1. 개요

기존 진행 중이던 수정/기능 작업(다운로드 수정 검증, 캐릭터 대화)과 macOS 네이티브 디자인 리빌딩을 하나의 버전으로 통합한다.

### 배경 (조사 결과)
- **다운로드 실패 원인 해결 완료**: `parseFormats`(YouTubeDLService.swift:261-380)에서 sb*/mhtml 포맷을 오디오로 오인하던 문제 수정 + yt-dlp 2026.08.19 교체. CLI 검증 완료, 앱 검증만 남음(T-1183).
- **NVIDIA 직접 API 불가**: 키체인 `NVIDIA_API_KEY`(nvapi- 접두어)는 chat completions 전 모델 403 `Authorization failed` — NVIDIA "Public API Endpoints" 권한 버그. 대안으로 **OpenRouter 경유** 확정.
- **캐릭터 대화 가능 모델 확정**: 키체인 `OPENROUTER_API_KEY`(sk-or-v1...) + `nvidia/nemotron-3-super-120b-a12b:free` + `reasoning.enabled=false` → 자연스러운 한국어 캐릭터 응답 성공. 앱에 키체인 접근 코드 없음 → KeychainHelper 신설 필요.
- **디자인 진단(macos-app-design 스킬)**: 사이드바 커스텀(`VStack+ScrollView`), 설정 커스텀(`SettingsRow+divider`), 메뉴바 `파일/편집/다운로더`만 존재, 툴바 `.automatic`, 창 크기/복원 미흡, Liquid Glass 미사용.

---

## 2. 결정 사항

| 항목 | 결정 |
|------|------|
| 타깃 OS | `.macOS(.v14)` → `.macOS(.v15)` (Sequoia+), macOS 26 Tahoe는 `#available` 분기로 Liquid Glass |
| 사이드바 | 커스텀 제거 → `List(selection:)` + `.listStyle(.sidebar)` (네이티브) |
| 설정 | 커스텀 `SettingsRow` 제거 → `Form` + `.formStyle(.grouped)` (네이티브), 상단 탭 유지 |
| 캐릭터 대화 백엔드 | OpenRouter + `nvidia/nemotron-3-super-120b-a12b:free` + `reasoning.enabled=false` |
| API 키 출처 | 키체인 우선(`SecItemCopyMatching`), OPENROUTER 우선 → NVIDIA 폴백 (사용자 지시) |
| 창 복원 | `NSWindow` autosave(`setFrameAutosaveName`) |
| AI 창 | 독립 새 창 유지 (멀티 윈도우 = 맥 표준, macos-app-design §9) |

---

## 3. 아키텍처

### 3.1 캐릭터 대화 (신규 기능)
```
CharacterChatView (새 창, 460×640)
  ├─ CharacterChatService.send(messages:) → OpenRouter /chat/completions
  │     model = nvidia/nemotron-3-super-120b-a12b:free
  │     reasoning.enabled=false, temperature=0.7
  │     system = 한국어 캐릭터 페르소나 프롬프트 + 대화 규칙
  ├─ KeychainHelper.read(service:account:) → OPENROUTER_API_KEY || NVIDIA_API_KEY
  └─ 대화 히스토리 UserDefaults 저장(영속) + 초기화 버튼
```
- 실제로는 **팟캐스트/요약용 OpenRouterService.swift:171-181 패턴 재사용** (LLMHTTPClient.swift 공통 POST 경유 가능).
- 별도 Reducer 없이 로컬 `@State` + `@MainActor` 서비스로 간결 구현 (YAGNI).

### 3.2 디자인 리빌딩
```
Phase 0 기반: Package.swift macOS15 + WindowFactory unified/autosave + GlassHelper
Phase 1 라이브러리: NavigationSplitView 3단 + List(.sidebar) + 툴바 unified/searchable + 창 1000×700
Phase 2 설정/메뉴: Form(.grouped) 8탭 + 보기/이동/도움말 메뉴 + About 시스템 패널
Phase 3 디테일: Material/glass + 다운로더 창 크기 + Player 단축키 + DebugLog 콘솔 + StatusBar 진행
```

---

## 4. 구현 단계 (T-번호)

### Step 1 — 캐릭터 대화 기능 (T-1184~T-1187) ✅
- T-1184: **KeychainHelper 신설** — `SecItemCopyMatching` 읽기/저장/삭제, OPENROUTER_API_KEY 우선 → NVIDIA_API_KEY 폴백 (Constants.swift)
- T-1185: **CharacterChatService** — OpenRouter 호출(nemotron-3-super:free + reasoning off), 한국어 캐릭터 시스템 프롬프트, 에러코드 E-MAC-AI-1004, 히스토리 저장/로드
- T-1186: **CharacterChatView UI** — 새 창(WindowFactory, id "chat", 460×640), 캐릭터 선택/대화 버블/입력바(⌘↩ 전송)/초기화, macOS 디자인 토큰 사용
- T-1187: **창/메뉴 연결** — AppDelegate openCharacterChatWindow + 메뉴/단축키 + 빌드 검증

### Step 2 — 디자인 P0 (T-1188) ✅
- T-1188: Package.swift macOS15 + WindowFactory `.unified`/autosave + GlassHelper(`#available(macOS 26)`) + 빌드

### Step 3 — 디자인 P1 라이브러리 (T-1189~T-1191) — 기존 T-1160/T-1162 흡수 (T-1189, T-1190 완료)
- T-1189: MainView → NavigationSplitView 2열(sidebar+detail, 앱 구조상 3번째 열 없음) + 창 1000×700/min 840×520 ✅
- T-1190: LibrarySidebarView → `List(.sidebar)` + 카운트/아이콘/드래그 리오더 재구현 (커스텀 배경 제거로 절충 — 드래그 복잡성) ✅
- T-1191: LibraryListView → 표준 `List` 전환(T-1162) + 툴바 unified/searchable + 빌드

### Step 4 — 디자인 P2 설정/메뉴 (T-1192~T-1194) ✅
- T-1192: SettingsView → `Form` + `.formStyle(.grouped)` (8개 탭, SettingsComponents 제거) ✅
- T-1193: 메뉴바 보기/창/도움말 추가 + 단축키 표시 + About 시스템 패널 ✅
- T-1194: 빌드 + 디버그 로그 + 스크린샷 ✅

### Step 5 — 디자인 P3 디테일 (T-1195~T-1197) — 기존 T-1166/T-1167 흡수 ✅
- T-1195: Material/glass 전환 + 다운로더 계열 창 크기 + DownloadRow ProgressView ✅
- T-1196: Player 상시 컨트롤(T-1166) + 패널 단축키 + DebugLog 콘솔 스타일(T-1167) ✅
- T-1197: StatusBar NSProgressIndicator + Toast 정리 + 전체 빌드/검증 ✅

---

## 5. 테스트 계획 (TC-번호)

| TC | 시나리오 | 방법 |
|----|---------|------|
| TC-1184 | 키체인 키 읽기(OPENROUTER 우선) + 누락 시 NVIDIA 폴백 | `security find-generic-password` 비교 + 서비스 로그 |
| TC-1185 | 캐릭터 대화 1건 왕복 + reasoning 비활성 확인 + 에러코드 | 앱 실행 + DebugPanel `[CACHE]`/`[ERROR]` |
| TC-1186 | 새 창 열기/닫기 + 대화 영속 + 초기화 | 빌드 후 실행, 창 오픈/종료 |
| TC-1189 | NavigationSplitView 2열 + 사이드바 접기(`⌘⌥S`) | 실행 검증 + a11y-dump |
| TC-1192 | 설정 8탭 Form 전환 후 각 컨트롤 동작 | 설정 창 수동 확인 |
| TC-1196 | Player 단축키(⌘⇧S/Q/P) + 컨트롤 상시 | 재생 중 키 입력 |
| TC-1183 | 다운로드 오디오/비디오 각 1건 (사용자 선행 검증) | 앱에서 URL 붙여넣기 |

---

## 6. 롤백 계획

- 각 Step 별도 커밋 → `git revert <commit>` 단위 롤백
- 창 복원 문제 시: autosave 제거만으로 원복
- List(.sidebar)/Form(.grouped) 문제 시: git revert + 기존 커밋 복원
- 캐릭터 대화 실패 시: 창 등록만 제거(서비스 코드 유지)

---

## 7. 성능 예산

| 지표 | 예산 | 비고 |
|------|------|------|
| Cold Start | ≤1.5s | 기존 유지 |
| 창 전환 | ≤300ms | NavigationSplitView 적용 |
| 캐릭터 응답 | ≤5s (무료 모델) | 비동기 스트리밍 아님, 로딩 인디케이터 |
| 메모리 | ≤300MB | 대화 히스토리 UserDefaults 제한(최근 50건) |

---

## 8. 에러코드 목록

| 코드 | 메시지 | 비고 |
|------|--------|------|
| E-MAC-AI-1004 | 캐릭터 응답을 가져오지 못했습니다. (네트워크/모델 상태 확인) | 신규 |

---

## 9. 문서/부가 업데이트

- docs/TODO.md v4.5 등록
- docs/CHANGELOG.md v4.5
- docs/DESIGN.md macOS 섹션 (캐릭터 대화 + 디자인 표준)
- error_message_ko.json E-MAC-AI-1004
- AGENTS.local.md macOS 타깃 15+ 반영
- docs/AI_MODELS.json default_chain에 캐릭터 모델 추가 여부 (참조용, 자동 사용 아님)