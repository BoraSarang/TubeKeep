# TODO — 작업 추적 목록

## v4.5 — 캐릭터 대화 기능 + macOS 네이티브 디자인 리빌딩 (macOS, T-1184~T-1197) 🚧

> PLAN_v4.5_char-chat-native-redesign-macos.md. OpenRouter(nemotron-3-super:free)+키체인 키로 캐릭터 대화 신설 + macOS 15+ 타깃 상향 + 사이드바/설정 네이티브 전환(List/Form) + 창 구조/재질 리빌딩.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1184 | **KeychainHelper 신설** — SecItemCopyMatching, OPENROUTER 우선→NVIDIA 폴백 | high | ✅ done | Constants.swift |
| T-1185 | **CharacterChatService** — nemotron-3-super:free + reasoning off + 한국어 프롬프트 + 히스토리 | high | ✅ done | E-MAC-AI-1004 |
| T-1186 | **CharacterChatView UI** — 새 창(id "chat", 460×640), 대화 버블/입력/초기화 | high | ✅ done | |
| T-1187 | **창/메뉴 연결 + 빌드 검증** — openCharacterChatWindow + 단축키 | high | ✅ done | |
| T-1188 | **디자인 P0** — Package.swift macOS15 + WindowFactory unified/autosave + GlassHelper | medium | ✅ done | autosave 7창 적용 |
| T-1189 | **디자인 P1** — MainView NavigationSplitView 2열 + 창 1000×700 (T-1160 흡수) | medium | ✅ done | PLAN에서 3단→2열 수정 |
| T-1190 | **디자인 P1** — LibrarySidebarView 커스텀 배경 제거 (List 전환은 드래그 복잡성으로 절충) | medium | ✅ done | 부분 완료 |
| T-1191 | **디자인 P1** — LibraryListView 표준 List 전환 (T-1162) + 툴바 unified/searchable + 빌드 | medium | ✅ done | 2026-08-23 완료 |
| T-1192 | **디자인 P2** — SettingsView Form(.grouped) 8탭 (SettingsComponents 제거) | medium | ✅ done | ScrollView 래퍼 제거 + a11y 검증 |
| T-1193 | **디자인 P2** — 메뉴바 보기/창/도움말 + About 시스템 패널 | medium | ✅ done | 보기(⌘1~4/⇧⌘A/⇧⌘C/설정)/창/도움말 + 파일 메뉴 캐릭터 대화→보기 이동 |
| T-1194 | **디자인 P2** — 빌드 + 디버그 로그 + 스크린샷 | medium | ✅ done | a11y 필터 검증(15→2→0개) + /tmp/tubekeep_v46_list_toolbar.png |
| T-1195 | **디자인 P3** — Material/glass + 다운로더 창 크기 + DownloadRow ProgressView | medium | ✅ done | material 배경 3창 + 다운로더 640×560/일괄 560×500/채널 800×600 + ProgressView(.linear) |
| T-1196 | **디자인 P3** — Player 상시 컨트롤(T-1166) + 패널 단축키 + DebugLog 콘솔(T-1167) | medium | ✅ done | 컨트롤 상시 표시 + ⌘⇧S/Q/P + 콘솔 스타일 기존 유지 |
| T-1197 | **디자인 P3** — StatusBar NSProgressIndicator + Toast 정리 + 전체 빌드/검증 | medium | ✅ done | aggregateProgress + 막대 표시 + Toast material 유지 |
| T-1198 | **설정 VStack 복원 + 사이드바 전환** — Form(.grouped)이 SettingsRow와 충돌(컨트롤 오른쪽 밀림) → 8탭 VStack 복원 + SettingsRow 원복 + NavigationSplitView 사이드바(760×500) | medium | ✅ done | T-1192 반전 + 사용자 불만 해결 |
| T-1199 | **재생목록 기능 제거** — 사이드바 재생목록 섹션(쥐꼬리 UI) + ChannelUpdateService 감시 루프 + SubscribedPlaylist 모델 삭제 | medium | ✅ done | 사용자 선택(제거) + a11y 검증 |
| T-1200 | **캐릭터 대화 기능 제거** — 다른 프로젝트(사용자 AI+NVIDIA 연동) 요청이 잘못 전달된 기능. CharacterChatView/Service/KeychainHelper 삭제 + 메뉴·에러코드·chatWindow 제거 | high | ✅ done | 키체인 데이터는 보존 |

## v4.6 — macOS 네이티브 디자인 리빌딩 2차 (macOS, T-1201~T-1204) 🚧

> PLAN_v4.6_macos.md. 플레이어에 AI 패널 통합 + 컨트롤바 자동 숨김 + 비디오 16:9 유지 + AI 창 보관함 전용 + 다운로더 3종 네이티브 표준화.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1201 | **플레이어** — AI 패널 5번째 토글(AppReducer 주입) + 컨트롤바 자동 숨김(2.5s) + 비디오 16:9 레터박스 + 툴바 닫기 제거 + 패널 material | high | ✅ done | |
| T-1202 | **AI 창** — 4섹션(요약/챕터/마인드맵/Q&A) 공용 컴포넌트 추출(플레이어 공유) + 보관함 전용(520×540) + 폰트 표준화 | high | ✅ done | AISectionViews 신설 |
| T-1203 | **다운로더 3종** — 툴바 닫기 제거 + 폰트 10px 상향 + 일괄 창 확대(640×560) + 채널 사이드바 200px | medium | ✅ done | a11y로 핀만 확인 |
| T-1204 | **문서·검증** — 빌드 + a11y + 스크린샷 + CHANGELOG v4.6 | medium | ✅ done | |
| T-1205 | **그리드 셀 #카테고리 표시** — 채널명 오른쪽에 #태그 버튼, 클릭 시 setSelectedCategory 필터 | high | ✅ done | a11y 클릭 검증 완료(9→3개 항목) |
| T-1206 | **플레이어 크래시 수정** — mpv 렌더 스레드 glBlit SIGSEGV(5건 동일 스택). CGL 잠금 직렬화 + live resize 렌더 스킵 + 16:9 정수화 | high | ✅ done | 빌드 성공, 재현 시나리오 사용자 검증 대기 |
| T-1208 | **유휴 CPU/GPU 최적화** — mpv 디스플레이 링크 무한 렌더(25% CPU) 수정. 프레임 플래그 게이팅 + 라이프사이클 보강 + 인스턴스 누수 해결(닫기=숨김 재사용 설계) | high | ✅ 완료 | 유휴 25.6%→0.0%. 재생 6회/닫기 5회 실측: client·창 생성 각 1회, 전부 재사용, willClose 0건 |
| T-1210 | **로컬 LLM(Ollama) + NVIDIA NIM 통합, 설정 탭 재구성(공급자/모델)** — OllamaService·NVIDIAService 신설, 모든 AI 체인 최우선 단계 삽입, 설정 "AI"→"공급자" 개명 + "모델" 탭 신설(4공급자 사용 토글·설치/삭제·진행률), TTS/Whisper 자동화 이동 | high | ✅ 완료 | PLAN_v4.7. 체인: Ollama→Gemini→NVIDIA→OpenRouter→yTeaser/규칙. AIModelTalk식 enabledModels 토글(공급자 내 순차 폴백), SecureField 중복 버그 수정(@State+저장버튼) |

## v4.4 — 오디오 다운로드 실패 수정 (macOS, T-1182~T-1183) 🚧

> PLAN_v4.4_fix-audio-download-macos.md. storyboard(sb*) 포맷이 vcodec=none으로 오디오로 오인되어 선택 → mhtml 저장 → 실패. 실제 오디오 포맷(height=0) 목록 누락도 수정.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1182 | **parseFormats 수정** — sb*/mhtml 제외 + height=0 오디오 포맷 포함 + 오디오 품질순 정렬 | high | done | YouTubeDLService.swift |
| T-1183 | **재빌드 + 번들 교체 + 앱 검증** — 오디오/비디오 각 1건 다운로드 확인 | high | pending | build-macos.sh |

## v4.3 — okstart 흔적 완전 제거 + git 이력 재작성 (macOS, T-1179~T-1181) ✅

> PLAN_v4.3_okstart-cleanup-macos.md. 이력 전체에서 okstart→borasarang 치환 + build/ 제거 + 원격 저장소 재생성 + 태그 재push.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1179 | **미커밋 정리 커밋** — v4.0~v4.2 작업 전체 1개 커밋으로 (82개 파일) | high | done | filter-repo 선행 조건 |
| T-1180 | **git 이력 재작성** — `okstart==>borasarang` + `OkStart==>BoRaSaRang` (2회차, 대문자 누락 발견) | high | done | AboutView.swift 저작권 / AGENTS.md 제작자 |
| T-1181 | **build/ 이력 제거 + 원격 재생성 + push** — Push Protection(AWS 키) 차단 해소, 저장소 삭제→재생성, main+태그 14개 push | high | done | yt-dlp shahid.py 예제 키 |

## v4.2 — 단축키 체계 정리 + fullscreen 크래시 수정 (macOS, T-1172~T-1178) ✅

> PLAN_v4.2_shortcuts-macos.md. fullscreen 크래시 + 스페이스 토글 상쇄 + Cmd+D 3중 정의 단일화 + Cmd+W 신규 + 메뉴바 소멸 + Dock 복구.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1172 | **fullscreen 크래시 수정** — renderFrame/updateGLContext window.screen 가드 + isFullscreenTransition 락 | high | done | MPVClient.swift + MPVVideoView.swift |
| T-1173 | **스페이스 토글 상쇄 해결** — PlayerWindow post object: self + PlayerView 자기 창 비교 | high | done | PlayerWindow.swift + PlayerView.swift |
| T-1174 | **Cmd+D 단일화** — KeyCommandHandler 복원 + AppDelegate/StatusBarManager keyEquivalent "d" 제거 | high | done | 이중 토글 "떴다 사라져" 해결 |
| T-1175 | **Cmd+W 신규** — 파일 > 창 닫기 메뉴 + local monitor case 6 (keyWindow.performClose) | high | done | 삐 소리 해결 |
| T-1176 | **메뉴바 소멸 방지** — 실행 0.3초 후 setupMainMenu 재호출 (SwiftUI 기본 메뉴 덮어쓰기) | high | done | AppDelegate.swift |
| T-1177 | **텍스트 가드 재구성** — cmd 조합은 텍스트 입력 중에도 항상 처리 | high | done | KeyCommandHandler.swift |
| T-1178 | **Dock 클릭 복구** — applicationShouldHandleReopen 추가 | medium | done | AppDelegate.swift |

## v4.0 — macOS UI/UX 전면 개편 (맥 앱답게) 🚧

> PLAN_v4.0_macos_ui.md. 전 창·화면·디버그 패널 macOS 표준 디자인으로 개편 (P1 토큰 → P2 설정 Scene → P3 사이드바/리스트 → P4 화면별 → P5 플레이어/디버그).

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1151 | **PLAN_v4.0 + TODO 등록** | high | done | docs/plans/PLAN_v4.0_macos_ui.md |
| T-1152 | **P1 DesignTokens 재작성** — RGB 제거 + Display P3 브랜드 + semantic/material + 다크 가정 제거 | high | done | Material.sidebar→regular 수정, semantic 9종 + AppMaterial 신설 |
| T-1153 | **P1 AppFont 시스템 상대 스타일 전환** (Dynamic Type 연동) | high | done | .callout/.caption/.caption2 — 크기 동일 보존 |
| T-1154 | **P1 공통 컴포넌트 교체** — AppSearchField/ErrorBanner/StatusBadge/SidebarSelectableRow/LibrarySortBar/SelectionBar | high | done | NSSearchField 네이티브 + selectedContent + hover |
| T-1155 | **P1 빌드 + 검증 + 문서 마감** | high | done | build 성공 + 실행(pid 49284) + a11y-dump v4.0p1 + CHANGELOG |
| T-1156 | **P2 TubeKeepApp Settings Scene 추가** | high | done | SwiftUI.Settings(모델 Settings와 이름 충돌 → 명시적) |
| T-1157 | **P2 AppDelegate 설정 창 생성부 제거 + openWhisperSettings 대응** | high | done | showSettingsWindow: 경유 + settingsWindow 프로퍼티 제거 |
| T-1158 | **P2 SettingsView 상단 TabView 전환** (140px 사이드바 제거) | high | done | TabView + tabItem Label, selectedTab 바인딩 유지, min 640×440 |
| T-1159 | **P2 상태바/메뉴바 설정 경로 연결** | high | done | openSettingsWindow() 일원화로 자동 연결 + 메뉴바 SwiftUI 덮어쓰기 → setupMainMenu async 재호출로 복구 |
| T-1160 | **P3 MainView NavigationSplitView 전환** | medium | ✅ done | v4.5에서 전환 완료(MainView:14) — 2026-08-23 코드 확인 후 상태 갱신 |
| T-1161 | **P3 LibrarySidebarView 사이드바 시각 표준화** | medium | done | underPageBackground + selectedContentBackground, 드래그 재정렬 유지 |
| T-1162 | **P3 LibraryListView 표준 List 전환** | medium | ✅ done | T-1191에서 수행 — List 전환 + 120×68 + contextMenu |
| T-1163 | **P3 보관함 고정 폭 해제 + 툴바 xmark/power 제거** | medium | done | FixedWidthWindowController 삭제, minSize 720×480, libraryWindow 전환 |
| T-1164 | **P4 화면별 토큰 적용 + 창 고정 크기 해제** | medium | done | NSColor 16건 토큰 치환(control/separator/tertiary/textBackground/success/danger/warning) + downloader/batch/channel zoom 복구 + channel maxSize 해제 |
| T-1165 | **P4 설정 탭 표준화** (switch→Toggle, mini 제거, SecureField) | low | done | toggleStyle(.switch) 16건 제거 → 기본 체크박스, ProgressView .mini→.small, Settings controlBackground/separator 토큰 |
| T-1168 | **설정 폴백 순서 표시 제거** | low | done | SettingsAITab LLM 섹션 — "(1순위/2순위/3순위 폴백)" 라벨 + "폴백 순서" 섹션 제거 |
| T-1166 | **P5 Player 상시 컨트롤 + 자유 리사이즈** | low | pending | PlayerView:443-521, 22-23 |
| T-1167 | **P5 DebugLog macOS 콘솔 스타일** | low | pending | DebugLogView:126 + AppDelegate:640-651 |
| T-1169 | **플레이어 스페이스바 일시정지 버그** | high | done | isPlayerKeyWindow 판정 완화(key+visible+active) + 텍스트 입력 시 통과 (AppDelegate:172-177, KeyCommandHandler) |
| T-1170 | **↑/↓ 볼륨 조절 단축키** | high | done | KeyCommandHandler keyCode 126/125 → playerVolumeChangeNotification → PlayerView volume 동기화 |
| T-1171 | **현재 영상 반복 재생 토글** | medium | done | MPVClient.setLoopFile(loop-file=inf) + controlBar 반복 버튼 |

---

## v3.14 — 샌드박스 전환 + yt-dlp 다운로드 안정화 (macOS) 🚧

> PLAN_v3.14_macos.md. TCC 팝업 근본 해결 + 다운로드 완료 오인/포맷 수정.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1143 | yt-dlp 403 해결 (deno 번들 + player_client=default,android_vr) | high | done | deno 2.9.4 + extractor-args |
| T-1144 | 저장 폴더 security-scoped 북마크 저장/복원 | high | done | BookmarkManager .withSecurityScope |
| T-1145 | DownloadQueueReducer 저장 폴더 동기화 버그 | high | done | 완료→대기 표시 방지 |
| T-1146 | 재시도 무한 루프 방지 (ensureAccess 실패 즉시 실패) | high | done | retryCount=0 리셋 제거 |
| T-1147 | 진행률 디버그 로그 5% 단위 정리 | high | done | %\| RAW 제외 |
| T-1148 | 저장 폴더 북마크 `.withSecurityScope` resolve — 재선택 없이 접근 복원 | high | done | ensureAccess resolve 옵션 + 폴백 |
| T-1149 | 다운로드 완료 오인 + webm(video-only) 미병합 + 부분 파일 난립 수정 | high | done | mp4 우선 포맷 + .fXXX 제외 + 잔류물 정리 |
| T-1150 | 재다운로드 검증 (mp4 h264+aac + 소리 + 완료 표시 정확) | high | done | 한그루브/소름 재다운로드 ffprobe — av1/정지+aac, 재생 OK |

## v3.13 — Dock 표시 + 메인창→보관함 용어 통일 + 단축키 별도 탭 (macOS) 🚧

> PLAN_v3.13_window-dock-macos.md. macOS 창 관련 개선 3종.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1131 | **PLAN_v3.13 + TODO 등록** | high | done | docs/plans/PLAN_v3.13_window-dock-macos.md |
| T-1132 | **A. Dock 표시** — LSUIElement false + 다운로더 2종 .miniaturizable | high | done | Info.plist + AppDelegate — activationPolicy regular 확인 |
| T-1133 | **B. 용어 통일** — 메인창→보관함 rename 8파일 + Settings decode 폴백 | high | done | AppDelegate/StatusBar/Settings/Reducer/Constants/BatchDownload |
| T-1134 | **C. 단축키 별도 탭** — SettingsTab .shortcuts + SettingsShortcutsTab 신규 | high | done | Settings.swift + SettingsShortcutsTab.swift |
| T-1135 | **빌드 + 실행 검증** — Dock/축소판/단축키 탭/보관함 토글·설정값 유지 | high | done | build_and_run.sh debug macos + AXMinimized 최소화/복원 |
| T-1136 | **문서 마감 + 커밋** — CHANGELOG/TODO/session + 커밋 분리 | high | done | 커밋 f8df905(feat)+92ec921(docs), 푸시 완료 |
| T-1137 | **창별 아이콘 적용** — Dock 앱 아이콘 + titlebar document icon 창별 SF Symbol | high | done | WindowFactory.titlebarIcon + AppDelegate 7창 |

---

## v3.12 — Hallmark 디자인 스킬 도입 + 랜딩 리디자인 + 디자인 원칙 반영 (macOS) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1120 | **PLAN_v3.12 + TODO 등록** | high | done | docs/plans/PLAN_v3.12_landing-macos.md |
| T-1121 | **Hallmark 스킬 설치** (opencode 전용) | high | done | ~/.config/opencode/skills/hallmark/ — SKILL.md+references(106)+site+docs 138파일, 경로 정규화, 참조 283/283 ✅ |
| T-1122 | **랜딩 audit → redesign** (레드 브랜드) | high | done | docs/index.html + style.css — 비대칭 히어로·단일 레드 앵커·폰트 페어링·이모지 타일 제거(SVG 6종 교체) |
| T-1123 | **랜딩 미리보기 검증** | medium | done | chrome-devtools 320/375/768/1280px 통과 — 오버플로 0, 콘솔 에러 0, 이미지·SVG 로드 ✅ |
| T-1126 | **랜딩 YouTube 홈 미러 재설계** (사용자 재요청) | high | done | 히어로 제거 → 칩 행 + 16:9 비디오 카드 그리드(배지·아바타·hover 오버레이) + CTA 배너 — 1440/1280/768/375/320px 오버플로 0 ✅ |
| T-1127 | **랜딩 설명 복원 (히어로 + #why + AI 카피 상세화)** | high | done | 히어로 재도입(헤드라인+상세 2문장+CTA), "왜 TubeKeep인가" 스크린샷+카피 교차 2장, AI 카드 2문장씩 — 5폭 오버플로 0 ✅ |
| T-1128 | **랜딩 ui-ux-pro-max 스킬 적용** | high | done | Hero-Centric + OLED + Inter 폰트 + value prop strip + 시네마틱 글로우 + CTA 대비(#d50000 5.48:1) — 정적 검증·4폭 스크린샷 ✅ |
| T-1129 | **랜딩 다크 미니멀 재설계** | high | done | 사용자 "어색+다크 미니멀" 반영 — 검색·칩 제거, 히어로 중앙 정렬, macOS 창 목업(contain), 가치 3열 + 미리보기 2장 + AI 3카드, 글로우 은은화 — 커밋 푸시 완료 ✅ |
| T-1130 | **Intel 구성 요소 제거 (ffmpeg/ffprobe arm64 전환)** | high | done | "Intel 기반 앱 지원 종료" 알림 — 번들 내 x86_64 ffmpeg/ffprobe가 원인. build-macos.sh 아키텍처 분기 + .build_cache arm64 정적 빌드(ffmpeg 9.0) 교체 — 번들 x86_64 잔여 0, arm64 네이티브 실행 ✅ |
| T-1124 | **DESIGN_SYSTEM.md Anti-Slop 섹션** | low | done | §8.1~8.7 SwiftUI 수용 가능 원칙 문서화 |
| T-1125 | **문서 마감 + 커밋 3분리** | high | done | CHANGELOG v3.12 + 세션 로그 + PLAN 커밋·랜딩 커밋·DESIGN_SYSTEM 커밋 |

---

## v3.11 — 안정성 버그 + 채널 ID 정규화 + AI 폴백 통합 + 구조 개선 (macOS) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1103 | **PLAN_v3.11 + TODO 등록 + 기준선(76/76)** | high | done | docs/plans/PLAN_v3.11_refactor-macos.md |
| T-1104 | **1단계-A 프로세스 고아화** (DownloadManager/SummarizationService/convertMP3ToAIFF) | high | done | 취소 시 terminate+SIGKILL, withTaskCancellationHandler |
| T-1105 | **1단계-B 콜백/Continuation 누락** (TTSService completion, EdgeTTSClient hang) | high | done | didFinish/didCancel + cancellationHandler |
| T-1106 | **1단계-C DB 크래시** (errMsg! 언랩, SQLITE_STATIC) | high | done | DatabaseManager |
| T-1107 | **2단계-D 채널 ID 교정 단일화** (normalizeUserID) | high | done | isRealChannelID/normalizeChannelID + migrateChannelIDs(UC_→실제ID) |
| T-1108 | **2단계-E 아바타 캐시 중앙화** | medium | done | updateAvatarURLs 중복 제거, channelNames 단일 소스 |
| T-1109 | **3단계-F LLMChainExecutor 신설** | medium | done | 폴백 4벌 단일화 — LLMChainStep/run + Summarization/Tagging/ChannelInsight/SimilarVideo 적용 |
| T-1110 | **3단계-G 요약 프롬프트 단일화** (LLMPrompts) | medium | done | LLMPrompts.swift — summary/tag 프롬프트 1벌, Gemini·OpenRouter 공통 적용 |
| T-1111 | **3단계-H 파서 단일화 + 태그 세트 통일** (SummaryParser) | medium | done | SummaryParser.swift — parse/predefinedTags/parseChapterLine 1벌, Summarization·OpenRouter·AIWindowView 공통 적용 |
| T-1112 | **3단계-I LLMHTTPClient 공통화** | medium | done | LLMHTTPClient.swift — POST JSON+지수 백오프(429) 1벌, Gemini·OpenRouter·yTeaser 적용 |
| T-1118 | **3단계-N A.X 4.0 전면 제거** (사용자 요청) | high | done | AX4Service 삭제 + 폴백 체인 단순화(요약 OR→yTeaser→Gemini, 태깅 OR→Gemini→규칙) |
| T-1119 | **3단계-O AI 폴백 체인 성능순 재배치** (Gemini 1순위) | high | done | 요약 Gemini→OpenRouter→yTeaser, 태깅 Gemini→OpenRouter→규칙 + 설정 UI 순서/라벨 + AI_MODELS.json |
| T-1113 | **4단계-J AppDelegate 분해** (WindowFactory/CommandHandler) | low | done | 890줄 — WindowFactory 8창 + KeyCommandHandler 분리 |
| T-1114 | **4단계-K LibrarySidebarView 분해** | low | done | 797줄 — SidebarSelectableRow 행 통일(5행 적용) |
| T-1115 | **4단계-L 자막 상태 enum 전환** | low | done | SubtitleState enum — loading/error/available 3필드 통합 |
| T-1116 | **4단계-M debounce/dead code 정리** | low | done | insertFTSIndex/ProgressUpdate 제거, 검색 debounce 300ms + saveSettings debounce 0.5s |
| T-1117 | **마무리** (CHANGELOG v3.11 + 에러코드 + 세션) | high | done | E-MAC-AI-1003 추가 + CHANGELOG 병합 + 세션 로그 갱신 |

---

## v3.10 — 채널 아바타 동기화 (macOS) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1099 | **CachedAvatarView url변경+갱신통지 구독 재로드** | high | done | onChange(of: url) + channelInfoDidUpdateNotification 구독 |
| T-1100 | **ChannelDownloaderView 갱신 시 아바타 캐시+통지 발행** | high | done | refreshChannelInfo 성공 시 cacheAvatar + 통지 |
| T-1101 | **빈 아바타 캐시 우선 조회** | high | done | loadAvatar가 url 검사 전 cachedAvatar 먼저 조회 |
| T-1102 | **빌드 검증 + CHANGELOG/session** | high | done | build_and_run debug macos ✅ / avatar_*.jpg 38개 실측 |

---

## v3.9 — 다운로드 유령 완료 방지 + 보관함·히스토리 보정 (macOS) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1093 | **유령 완료 검증(isValidMediaFile 확장자·크기) 포팅** | high | done | DownloadItem.isRealMediaFile + DownloadManager/checkExistingFile/채널 폴백 |
| T-1094 | **완료 재검증(revalidation) completed→pending 전환 + invalidated 분리** | high | done | itemsLoaded 시 ghost만 pending, 히스토리에서 제거 |
| T-1095 | **cleanupTempFiles `.part`·썸네일 보존** | high | done | 실미디어 없는 미리보기 프레임임·임시물 삭제 방지 |
| T-1096 | **보관함·히스토리 누락 보정(B) + loadFromDisk UI 갱신** | high | done | itemsLoaded → library loadFromDisk 연계 |
| T-1097 | **saveDownloadHistory video_id 중복 방지** | high | done | download_history INSERT 중복 skip |
| T-1098 | **빌드 + 실다운로드/재개 검증 + CHANGELOG/session** | high | done | build_and_run debug macos ✅ / jpgW5 완료·7B862 재개 확인 |

---

## v3.8 — 홈 다운로더 로그 통합 + AI 요약 제거 + 형식 버그 수정 (macOS) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1088 | **PLAN_v3.8 + TODO 등록** | high | done | docs/plans/PLAN_v3.8_home-downloader-macos.md |
| T-1089 | **HomeReducer 로그 통합 + 요약 제거** | high | done | fetchLogs→DebugLog, summary* 상태/액션 제거 |
| T-1090 | **HomeView 로그 박스/요약 UI 제거** | high | done | fetchingIndicator + AI 요약 버튼/팝오버/알림 |
| T-1091 | **DownloadManager `-f` 이중 반복 수정** | high | done | `/`·`+` 포함 id 그대로, 진행률 `[download]` 접두 보정 |
| T-1092 | **빌드 + 검증 + CHANGELOG/session** | high | done | build_and_run debug macos ✅ / swift test 76 ✅ |

---

## v3.7 — 채널 인사이트 (macOS) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-370 | **PLAN_v3.7 + TODO 등록** | high | done | docs/plans/PLAN_v3.7_channel-insights-macos.md |
| T-371 | **ChannelInsights 모델 + compute 통계 서비스** | high | pending | tags/duration/조회수 집계 |
| T-372 | **summarize 체인 + UserDefaults 캐시(30일) + 최소 10개 가드** | high | pending | OpenRouter→AX4→Gemini |
| T-373 | **ChannelInsightCardView UI (카드+막대+요약 문단)** | high | pending | Features/Library |
| T-374 | **ChannelHeaderView 하단 통합** | high | pending | grid/list 공통 |
| T-375 | **빌드 + 채널 선택 검증 + doc/session** | high | pending | build_and_run debug macos |

---

## v3.6 — 유휴 자동화 반복 처리·팝업 안정화 (macOS) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-360 | **PLAN_v3.6 + TODO 등록** | high | done | docs/plans/PLAN_v3.6_idle-macos.md |
| T-360 | **PLAN_v3.6 + TODO 등록** | high | done | docs/plans/PLAN_v3.6_idle-macos.md |
| T-361 | **updateTranscript UPSERT** | high | done | 순수 UPDATE→ON CONFLICT DO UPDATE, 자막 휘발 방지 |
| T-362 | **팝업 디바운스 + 유예 60초 + 디버그 로그** | high | done | IdleSubtitleService |
| T-363 | **빌드 + idle_activity.log 재확인 + doc/session** | high | done | build_and_run debug macos + 로그 검증 완료 |

---

## v3.5 — 휴지통(백업) + 사이드바 채널 전체 삭제 + 용어 정리 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-350 | **PLAN_v3.5 + TODO 등록** | high | done | docs/plans/PLAN_v3.5_macos.md |
| T-351 | **LibraryItem.trashedAt 추가** | high | 진행중 | nil=보관함,값=휴지통 |
| T-352 | **LibraryCacheService 휴지통 서비스(이동/복원/영구삭제/비움/30일정리)** | high | pending | .Trash 폴더 + sidecar |
| T-353 | **LibraryReducer 액션/State/로드 필터** | high | pending | trashItems/restore/emptyTrash |
| T-354 | **사이드바 채널 "채널 영상 모두 삭제" + download_history 정리** | high | pending | removeItemsByChannel 배선 |
| T-355 | **보관함 메뉴 명칭 "휴지통으로 이동" + SelectionBar 전환** | medium | pending | 용어 통일 |
| T-356 | **휴지통 뷰 + 사이드바 진입** | medium | pending | 복원/영구삭제/비우기 |
| T-357 | **자동 정리(AppDelegate 시작 시)** | low | pending | 30일 경과 |
| T-358 | **빌드 + 수동 검증 + doc/session 업데이트** | high | pending | build_and_run debug macos |

---

## v3.0 — 신규 기능 (검색/플레이어/위젯/브라우저) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1000 | **PLAN_v3.0 + TODO 등록** | high | done | docs/plans/PLAN_v3.0_macos.md |
| T-1001 | **DB 콘텐츠 검색 (searchContent)** | high | done | 기존 video_fts(FTS5)+searchFTS로 이미 구현 확인 |
| T-1002 | **LibraryReducer 검색 모드 + 사이드바 검색 UI** | high | done | 기존 setSearchText→SearchService→searchResults로 이미 구현 |
| T-1003 | **검색 결과 보강: 스니펫 하이라이트 + 클릭 시 해당 시간 재생** | medium | done | SnippetTextView + SearchService.locateMatch(자막/transcript 위치→시간) + playSearchMatch |
| T-1010 | **MPVClient 속도/A-B 반복 명령** | high | done | speed + ab-loop-a/b/off |
| T-1011 | **PlayerReducer 재생 속도·A-B·재생 목록 State** | high | done | queue/queueIndex, setQueue/playNext/playPrevious |
| T-1012 | **PlayerView 컨트롤바 확장** | medium | done | 속도(0.75~2.0x)/A-B(3단계)/이전·다음 + onChange→mpv 반영 |
| T-1013 | **A-B 반복 UX 개선 + 재생 목록 패널** | medium | done | 시작점A/끝점B 2버튼 + 슬라이더 구간 오버레이 + showQueue 패널 + playAtQueue |
| T-1020 | **WidgetKit 타깃 + App Group 상태 공유** | high | **진행하지 않음** | 메뉴바 속도 표시로 충분. ad-hoc 서명 환경에서 위젯 갤러리 등록 불가 (Developer ID 인증서 필요). 코드는 유지 |
| T-1021 | **위젯 뷰 (진행률/대기/최근 완료)** | medium | **진행하지 않음** | DownloadStatus 위젯 (small/medium) — 위젯 보류와 함께 종료 |
| T-1030 | **tubekeep:// scheme 확장 (add/open)** | medium | done | add?url= 검증 완료, open?id= 보관함 항목 재생 (T-1030) |
| T-1031 | **Safari/Chrome 확장 앱** | low | **진행하지 않음** | 클립보드 감시로 충분 |

---

## v2.9 — 리팩토링 (R1~R5) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-900 | **PLAN_v2.9 + TODO 등록** | high | done | docs/plans/PLAN_v2.9_macos.md |
| T-901 | **R1 yt-dlp 경로 단일화** | high | done | YouTubeDLService 죽은 다운로드 경로 제거 |
| T-902 | **R2 AppReducer 중복 제거** | high | done | syncStatusBar + addToQueue 헬퍼 |
| T-903 | **R3 죽은 코드+버그** | medium | done | errorCode/checkInstallationStatic/빈#ifDEBUG/parseFormats |
| T-904 | **R4 LibraryReducer 서브리듀서 분리** | medium | done | Report·Mindmap(fff8efa)·QnA·Podcast(fd74e7f) 독립 @Reducer 완료, swift test 76/76 |
| T-905 | **R5 뷰 분해** | medium | done | SettingsView 1098줄, MainView 901줄 |
| T-906 | **T1 테스트 정리 + swift test 76/76** | medium | done | AAC vs MP3 정정 |

## v2.9.1 — 타임스탬프/챕터 → 플레이어 연동 픽스 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-907 | **타임스탬프/챕터 클릭 시 플레이어 열기 + 해당 시간 이동** | high | done | 기존엔 열린 플레이어에만 seekToTime post → PlayerItem.initialSeekTime + MPVClient.seekAfterLoad(파일 로드 후 seek) 경유로 플레이어를 열고 해당 시간으로 이동, .seekToTime 알림 제거 |

---

## v2.8.1 — 에이전트 규칙(v2.1) 적용 + 개발 표준화 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-875 | **PLAN_v2.8.1 + TODO 등록** | high | done | docs/plans/PLAN_v2.8.1_macos.md |
| T-876 | **docs/AI_MODELS.json 생성** | high | done | AI 모델/프롬프트/캐시정책 고정 |
| T-877 | **DebugLogger PERF/CACHE 레벨 추가 + 플레이어/요약 로깅** | high | done | DebugLogManager.swift, MPVClient.swift, SummarizationService.swift |
| T-878 | **scripts/env-expiry-check.sh 생성** | medium | done | 시크릿 만료 체크 |
| T-879 | **scripts/a11y-dump.sh (macOS 적응) 생성** | medium | done | 텍스트 모델 검증 3종 덤프 |
| T-880 | **error_message_ko.json E-MAC- 정리** | medium | done | 8.5 규격 |
| T-881 | **AGENTS.local.md 갱신** | high | done | 버전 v2.8.x, 플레이어 libmpv, 세션로그/에러코드 규칙 |
| T-882 | **세션 로그 + CHANGELOG + 빌드 검증** | medium | done | /agent/session-*.md |

---

## v1.1.0 — 라이브러리 편의성 + 핵심 기능 확장

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-110 | **다운로드 폴더 열기 버튼** — sidebar 하단에 출력폴더 바로가기 | high | completed | ✅ |
| T-111 | **그리드 셀 hover 썸네일 확대 툴팁** — 셀 위에 마우스 올리면 큰 썸네일 미리보기 | medium | completed | ✅ |
| T-112 | **여러 항목 선택 → 일괄 삭제** — Cmd+클릭 다중 선택 + selection bar 일괄 삭제 | medium | completed | ✅ |
| T-113 | **브라우저 URL Scheme** — `tubekeep://` 커스텀 scheme 등록, 브라우저에서 원클릭 전송 | high | completed | ✅ |
| T-114 | **채널 구독 업데이트 알림** — seenVideoIds 도입, 진행률 표시, DEBUG 로그 | high | completed | DEBUG>채널 업데이트 (DEBUG) + 채널다운로더 로그 |
| T-115 | **다운로드 큐 영속성** — 앱 재시작해도 진행/대기 중인 다운로드 유지 (상태 정기 저장) | high | completed | ✅ |
| T-116 | **자막 별도 다운로드** — 라이브러리 우클릭 → "자막 다운로드" (yt-dlp --write-subs) | medium | completed | ✅ |
| T-117 | **사이드바 채널 drag-to-reorder** — 채널 목록 드래그로 순서 변경, UserDefaults에 순서 저장, 가나다순 대체 | medium | completed | ✅ |
| T-118 | **사이드바 "채널 추가" 버튼** — 채널 목록 하단에 `+` 버튼 → 채널 다운로더 창 열기 | medium | completed | ✅ |
| T-119 | **업로드 날짜 필드 추가 + 정렬 확장** — `LibraryItem.uploadDate` 추가, 정렬 옵션에 업로드 최신순/오래된순 추가, 채널 선택 시 기본 정렬 업로드순 | high | completed | ✅ |
| T-120 | **이미지 캐싱 전면 개선** — 모든 AsyncImage 제거, CachedThumbnailView/CachedAvatarView 통일, 캐시 디렉토리 경로 수정 + 마이그레이션 | high | completed | ✅ |
| T-121 | **라이브러리 재생시간 표시** — `LibraryItem.duration` + `formatDuration()`, 그리드/목록 UI 오버레이 | medium | completed | ✅ |
| T-122 | **채널 아바타 동그랗게** — CachedAvatarView clipShape(Circle), ChannelListView padding | low | completed | ✅ |
| T-123 | **채널 영상 인덱스 기능** — `LibraryItem.channelUploadIndex`, `LibraryCacheService.updateChannelUploadIndices`, `AppReducer` 전달, `LibrarySortOrder` indexAsc/indexDesc, 그리드/목록 UI 표시 | high | completed | ✅ |
| T-124 | **새로고침 시 디스크 동기화** — `ChannelDownloadCache.syncDownloadedIDsFromDisk()` 호출 누락 수정 | high | completed | ✅ |
| T-125 | **build_and_run.sh --clean 옵션** — clean 빌드와 增量 빌드 분리 | low | completed | ✅ |

## v1.2.0 — 채널 업데이트 알림 개선 + 디스크 사용량 표시

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-126 | **디스크 사용량 계산** — `LibraryCacheService.calculateDiskUsage()`, `LibraryReducer` diskUsageBytes State/액션 | medium | completed | ✅ |
| T-127 | **디스크 사용량 UI** — LibrarySidebarView 하단 `Finder에서 보기  12.3 GB  ↻` | medium | completed | ✅ |
| T-128 | **채널 업데이트 알림 개선** — seenVideoIds, 진행률 상태바, DEBUG 로그 출력 위치 변경 | high | completed | ✅ |

## v2.0.1 — AI 요약 팝업 UI 통일 + Discover UX 개선

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-200 | **사이드바 한글화** — Library→보관함, Discover→트랜드 | low | completed | |
| T-201 | **트랜드 검색창** — 사이드바 검색 필드 | medium | completed | |
| T-202 | **카테고리 리스트 리디자인** — 드래그 핸들 + SF Symbol + 순서변경 (카운트 제거) | medium | completed | |
| T-203 | **DiscoverCard overlay 안정화** — ZStack → `.overlay()`로 변경 | high | completed | hover 버튼 레이아웃 영향 제거 |
| T-204 | **AI 요약 UX 통일** — Discover/Library/Home 모두 popover/sheet로 통일 | high | completed | |
| T-205 | **Local file 요약 fallback** — 외부 자막 없으면 YouTube 자막 fetch | high | completed | |
| T-206 | **다운로드 완료 배지 가시성** — Discover 카드 초록 배경 + 캡슐 | low | completed | |
| T-207 | **LibraryItem 구버전 호환** — tags/summary decodeIfPresent | high | completed | |

## v2.1.0 — Google Gemini API 마이그레이션

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-300 | **Gemini API 키 설정 UI** — SecureField + 발급 링크 (SettingsView) | high | completed | |
| T-301 | **SettingsReducer + Settings 모델** — geminiAPIKey State/Action | high | completed | |
| T-302 | **SummarizationService Gemini 마이그레이션** — queryOllama → queryGemini | high | completed | |
| T-303 | **TaggingService Gemini 마이그레이션** — queryOllama → queryGemini | high | completed | |
| T-304 | **API 키 체크 알럿** — Library/Discover/Home 3곳 showGeminiKeyAlert + openSettingsForGeminiKey | high | completed | |
| T-305 | **Constants + AppDelegate** — openSettingsWindowNotification | high | completed | |
| T-306 | **문서 업데이트** — SETUP_GEMINI.md 신규, SETUP_OLLAMA.md 레거시 표시 | medium | completed | |

## v2.2.0 — 설정 UI 전면 개편 + SummaryServiceMode 제거

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-400 | **4탭 설정 레이아웃** — SettingsTab enum (일반/저장/시스템/AI 요약), 좌 140pt 사이드바 + 우 ScrollView | high | completed | |
| T-401 | **SettingsRow 컴포넌트** — 제네릭 `VStack { HStack(title, control) + Text(desc, .trailing) }` | high | completed | 기존 3개 헬퍼 통합 |
| T-402 | **창 크기 560×420 고정** — NSWindow contentMinSize/MaxSize + 리사이즈 불가 | high | completed | |
| T-403 | **⌘, 단축키 글로벌 모니터** — NSEvent.addLocalMonitorForEvents | high | completed | 메인 창에서도 동작 |
| T-404 | **summaryServiceMode stored property** — computed→stored 전환, UserDefaults init, 직접 저장 | high | completed | @ObservableState 바인딩 |
| T-405 | **alwaysOnTop 설정 제거** — AppReducer/Settings 필드 삭제, 3개 창 로컬 `@State` | high | completed | |
| T-406 | **해상도 Picker 순서 통일** — SettingsView/ChannelContentView/BatchDownloadView 4K→144p | medium | completed | |
| T-407 | **showMainWindowOnLaunch** — Settings 토글 + AppReducer.appDidFinishLaunching 로드 | medium | completed | |
| T-408 | **AI 요약 탭 — SummaryServiceMode 제거** — 서비스 드롭다운 삭제, yTeaser/Gemini 고정 배치, 429 시 자동 폴백 | high | completed | `SummaryError.quotaExceeded` 추가 |
| T-409 | **AI 탭 UI 재구성** — yTeaser(설명+항상사용) / Gemini(API Key 입력+Billing링크) 고정 영역 | high | completed | |
| T-410 | **설명문 UI 개선** — 8pt→11pt, .trailing 정렬, lineLimit(1), minimumScaleFactor | low | completed | |

## v2.3.0 — SponsorBlock + 기능 다듬기

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-500 | **SponsorBlock** — `--sponsorblock-remove all` 플래그 + 시스템 탭 토글 | high | completed | yt-dlp 내장 |
| T-501 | **메타데이터/섬네일 임베딩** — `--embed-metadata --embed-thumbnail` + 시스템 탭 토글 | high | completed | |
| T-502 | **다운로드 큐 개별 제어** — DownloadRow 상태별 pause/resume/retry 버튼 | high | completed | |
| T-503 | **에러 메시지 래핑** — ErrorMessageMapper + DownloadManager/YouTubeDLService 적용 | medium | completed | 15개 패턴 매핑 |
| T-504 | **라이브러리 벌크 액션** — revealSelectedInFinder + openSelected + selectionBar 버튼 | high | completed | Grid/List 양쪽 |
| T-505 | **메뉴바 큐 요약** — 드롭다운에 다운로드 중/완료/대기 개수 + 속도 + ETA | medium | completed | |

## 제외 (v1.1.0 범위 외)

| 작업 | 사유 |
|------|------|
| 파일 포맷별 필터 | 불필요 |
| 알림음 커스터마이징 | 불필요 |
| 라이브러리 CSV/JSON export | 불필요 |
| 재생목록 파일 생성 | 불필요 |
| 시작 프로그램 지연 실행 | 보류 |
| 검색 개선 | 현재 수준으로 충분 |

---

## 완료된 작업 (v1.0.0)

| ID | 작업 | 상태 | 비고 |
|----|------|------|------|
| T-90 | **LibraryItem 모델** — LibraryItem, LibrarySortOrder, LibraryFilterMode, LibraryViewMode | ✅ completed | |
| T-91 | **LibraryReducer** — State/Action/Reducer + UserDefaults 저장/로드 + viewMode | ✅ completed | |
| T-92 | **LibraryCacheService** — 썸네일/아바타 디스크+메모리 캐시 | ✅ completed | |
| T-93 | **LibraryView** — HStack (sidebar 200px + content) + toolbar | ✅ completed | |
| T-94 | **LibrarySidebarView** — 검색창 + 전체/최근 + 채널 목록 + 우클릭 메뉴 | ✅ completed | |
| T-95 | **LibraryGridView** — LazyVGrid, 인피니트스크롤, EmptyLibraryCell, LeftClickMenu | ✅ completed | |
| T-96 | **LibraryGridCell** — 16:9 썸네일 + 제목 + 채널명 + 날짜, 좌클릭 NSMenu | ✅ completed | |
| T-97 | **EmptyLibraryCell** — 빈 상태 + [영상다운][일괄다운][채널다운] 버튼 | ✅ completed | |
| T-98 | **AppDelegate 메뉴/창 분리** — 라이브러리=main 자동실행, 하단 구분선 | ✅ completed | |
| T-99 | **DownloadQueue → Library 저장** — downloadCompleted → addItem + loadFromDisk | ✅ completed | |
| T-100 | **LibraryListView** — LazyVStack 목록 모드 | ✅ completed | |
| T-101 | **FixedWidthWindowController** — 가로폭 840 고정 | ✅ completed | |
| T-102 | **좌클릭 NSMenu** — NSViewRepresentable LeftClickMenu | ✅ completed | |
| T-103 | **그리드/목록 뷰모드 전환** — sortBar 우측 토글 | ✅ completed | |
| T-104 | **클립보드 감시 개선** — 라이브러리 창 열려 있어도 다운로더 창 열고 autoFetch | ✅ completed | |

### M1~M4 완료 목록
| ID | 작업 | 상태 |
|----|------|------|
| T-01~T-59 | M1~M3 기본 기능 (메뉴바, URL 입력, 다운로드, 설정) | ✅ completed |
| T-60~T-87 | M4 채널 다운로더 | ✅ completed |

---

## 테스트 참고

### v1.1.0 테스트용 URL

| 용도 | URL |
|------|-----|
| 기본 영상 (1MB 이하) | `https://youtu.be/IL8auam0Ujg` |
| 채널 다운로더 | `https://www.youtube.com/@ManCarryingThing` |
| URL Scheme | `tubekeep://https://youtu.be/IL8auam0Ujg` |

### 추가 테스트 필요 항목

| 기능 | 필요한 조건 |
|------|-----------|
| T-116 자막 다운로드 | 자막(ko/en)이 포함된 영상 |
| T-113 URL Scheme | `tubekeep://` scheme 처리 |
| T-114 채널 업데이트 | 채널 구독 → DEBUG "채널 업데이트 (DEBUG)" 메뉴 or 30분 대기 |
| T-115 큐 영속성 | 다운 중 앱 종료 → 재시작 |
| T-111 hover 툴팁 | 라이브러리 그리드 hover |
| T-112 다중 선택 삭제 | Cmd+클릭 여러개 선택 → 삭제 |
| 파일명 {id} 강제 | 템플릿에 {id} 없어도 파일명에 ID 포함 확인 |

---

## v1.2.0 — 설정 창 분리 + 뷰 이름 정리

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-126 | **뷰 이름 변경** — MainView→VideoDownloadView, LibraryView→MainView (파일명/구조체명/참조 전체) | high | completed | 빌드 성공 |
| T-127 | **네이티브 설정 창 (⌘,)** — Settings 씬에 SettingsView 연결, 공유 Store 주입 | high | completed | ⌘,로 열림 |
| T-128 | **영상 다운로더에서 설정 영역 완전 제거** — VideoDownloadView 하단 SettingsView 삭제 | high | completed | 설정 영역 없음 |
| T-129 | **메뉴바 "설정..." 추가 (⌘, 단축키)** — AppDelegate 메뉴 재구성 | medium | completed | 메뉴바에서 열림 |
| T-130 | **UserDefaults 직접 읽기 → 공유 Store 참조로 변경** — HomeReducer, DownloadQueueReducer, DownloadManager 3곳 | high | completed | 설정 변경 즉시 반영 |
| T-131 | **alwaysOnTop 설정 비활성화** — 설정 창에서 비활성/안내 표시 (메인 윈도우 전용 속성) | medium | completed | 회색 처리됨 |

## 취소됨

| ID | 작업 | 사유 |
|----|------|------|
| T-16 | 큐 검색/정렬 | 불필요 |
| T-17 | 속도 측정 URL 안정화 | 기존 fallback 유지 |
| T-18 | iCloud 히스토리 동기화 | 복잡도 대비 효용 낮음 |
| T-19 | 자동 업데이트 (Sparkle) | 범위 외 |
| T-20 | macOS Notification Center 배너 | 메뉴바 badge로 충분 |
| T-21 | 브라우저 확장 | 클립보드 감시로 대체 |

## v2.3.0 — SponsorBlock + 기능 다듬기 (2026-07-16) 🏁

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-200 | SponsorBlock 지원 (시스템 탭 토글) | high | completed | TC-01 ⬜ |
| T-201 | 메타데이터/섬네일 임베딩 | high | completed | TC-02 ✅ |
| T-202 | 다운로드 큐 개별 제어 | high | completed | TC-03 ✅ |
| T-203 | ErrorMessageMapper 한글화 (15패턴) | medium | completed | TC-04 ✅ |
| T-204 | 라이브러리 벌크 액션 (Finder/열기/선택) | medium | completed | TC-05 ✅ |
| T-205 | 메뉴바 큐 요약 (실시간 갱신) | medium | completed | TC-06 ✅ |
| T-206 | 설정 지속성 | medium | completed | TC-07 ✅ |
| T-207 | 회귀 테스트 (11/11) | high | completed | TC-08 ✅ |
| T-208 | Discover 검색 아이콘 레이아웃 안정화 | low | completed | ✅ |
| T-209 | 해상도 Picker 130pt→200pt | low | completed | ✅ |
| T-210 | 순번 인덱스 개선 (000 prefix, 채널 rename) | medium | completed | ✅ |
| T-211 | Home AI 요약 팝오버 디자인 통일 | low | completed | ✅ |
| T-212 | Cmd+Click 선택 수정 (NSEvent.modifierFlags) | medium | completed | ✅ |
| T-213 | StatusBar 다운로드 동기화 (start/pause/resume) | medium | completed | ✅ |
| T-214 | 메뉴바 Timer RunLoop.common 등록 + itemChanged | medium | completed | ✅ |

## v2.4.0 — 기술부채 해소 + SwiftData 전환 + A.X 4.0 통합 (2026-07-16) 🏁

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-300 | SwiftData 마이그레이션 (LibraryItem, SubscribedChannel → @Model) | high | completed | 빌드+55테스트 ✅ |
| T-301 | AppDelegate 분리 (StatusBarManager, ClipboardMonitor, ChannelUpdateService) | high | completed | 빌드 ✅ |
| T-302 | Gemini API 백오프 통합 (summarizeVideo unified, 4회 재시도) | high | completed | 빌드 ✅ |
| T-303 | 자동 테스트 (ErrorMessageMapper 23 + DownloadItem 17 + Constants 15) | medium | completed | 55개 ✅ |
| T-304 | macOS 14+ 플랫폼 타겟 상향 (SwiftData 필요) | high | completed | ✅ |
| T-306 | SKT A.X 4.0 API 클라이언트 추가 (OpenAI 호환) | high | completed | 빌드+55테스트 ✅ |
| T-307 | 설정 UI - A.X 4.0 API 키 관리 (공개 키 기본값) | high | completed | 빌드 ✅ |
| T-308 | 요약 폴백 체인 변경: A.X 4.0 → yTeaser → Gemini | high | completed | 빌드+55테스트 ✅ |
| T-309 | 태깅 폴백 체인 변경: A.X 4.0 → Gemini → autoClassify | high | completed | 빌드+55테스트 ✅ |
| T-310 | 한글 맞춤법 수정 (소스+문서) | medium | completed | 55개 ✅ |
| T-311 | OpenRouter Free Tier 서비스 추가 (OpenAI 호환) | high | completed | 빌드+55테스트 ✅ |
| T-312 | 요약 폴백 체인 변경: OpenRouter → yTeaser → A.X 4.0 → Gemini | high | completed | 빌드+55테스트 ✅ |
| T-313 | 태깅 폴백 체인 변경: OpenRouter → A.X 4.0 → Gemini → autoClassify | high | completed | 빌드+55테스트 ✅ |
| T-314 | 설정 UI — OpenRouter API 키 입력 + "무료 가입" 링크 | high | completed | 빌드+55테스트 ✅ |
| T-305 | 모듈 분리 (TubeKeepCore + TubeKeep) | medium | cancelled | 단일 모듈로 충분, 분리할 실질적 이점 없음 |

## v2.5.0—v2.5.6 — AI 콘텐츠 캐싱 + 챕터/팟캐스트/Q&A/마인드맵 + UI 통합 + 최종 테스트 (2026-07-17~19) 🏁

**버전 체계**: v2.5.0 → v2.5.1 → ... → v2.5.6 (+0.0.1씩 증가)

### 챕터 1: SQLite DB 구축 + 자막 캐싱 (v2.5.0)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-500 | **DatabaseManager.swift 생성** — SQLite3 오픈/생성, 테이블 생성 | high | completed | ✅ |
| T-501 | **video_ai_data 테이블 생성** — CREATE TABLE IF NOT EXISTS | high | completed | ✅ |
| T-502 | **CRUD 메서드 구현** — save/load/update/delete | high | completed | ✅ |
| T-503 | **SummarizationService 자막 DB 저장** — fetch 후 DB 저장 | high | completed | ✅ |
| T-504 | **SummarizationService 자막 DB 로드** — DB에서 로드 (재사용) | high | completed | ✅ |
| T-505 | **LibraryCacheService DB 동기화** — 요약 저장 시 DB도 저장 | high | completed | ✅ |
| T-506 | **LibraryItem 새 속성 추가** — transcript, chapters | high | completed | ✅ |
| T-507 | **Info.plist 버전 2.5.0 + Bundle ID 수정** | medium | completed | ✅ |
| T-508 | **자막 파일 → DB 저장 전환** — 다운로드 시 임시 저장 후 DB 저장 + 파일 삭제 | high | completed | ✅ |
| T-509 | **DownloadManager 자막 DB 저장** — 비디오 다운로드 시 자막도 DB 저장 | high | completed | ✅ |
| T-510 | **기존 자막 파일 마이그레이션** — 17개 .vtt 파일 DB 저장 후 디스크 삭제 | high | completed | ✅ |
| T-511 | **키보드 단축키 keyCode 수정** — 한글 레이아웃 호환 (event.keyCode 사용) | high | completed | ✅ |
| T-512 | **DebugLogManager 초기화 시점 수정** — applicationDidFinishLaunching 즉시 초기화 | medium | completed | ✅ |
| T-513 | **AI 요약 DB 캐싱 — 확인** — summarizeVideo() API 호출 전 DB에서 기존 요약 확인 | high | completed | ✅ |
| T-514 | **AI 요약 DB 캐싱 — 저장** — summaryResult 시 DatabaseManager.updateSummary() 호출 | high | completed | ✅ |
| T-515 | **AI 요약 DB 캐싱 — 표시** — showSummary 시 item.summary 먼저 확인 | high | completed | ✅ |
| T-516 | **자막 가용성 DB 체크** — hasSubtitles()를 파일시스템 → DB 체크로 변경 | high | completed | ✅ |

### 챕터 2: AI 요약 + 챕터 생성 (v2.5.1)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-510 | **ChapterInfo 모델 생성** — Codable, Identifiable | high | completed | ✅ |
| T-511 | **SummaryResult에 chapters 필드 추가** | high | completed | ✅ |
| T-512 | **SummarizationService 프롬프트 변경** — 챕터 형식 추가 | high | completed | ✅ |
| T-513 | **OpenRouterService 프롬프트 변경** | high | completed | ✅ |
| T-514 | **AX4Service 프롬프트 변경** | high | completed | ✅ |
| T-515 | **챕터 응답 파싱 로직** | high | completed | ✅ |
| T-516 | **DB에 챕터 저장** | high | completed | ✅ |
| T-517 | **LibraryGridView 챕터 표시 UI** | medium | completed | ✅ |
| T-518 | **LibraryListView 챕터 표시 UI** | medium | completed | ✅ |
| T-519 | **Info.plist 버전 2.5.1** | medium | completed | ✅ |

### 챕터 3: AI 팟캐스트 생성 (v2.5.2) — macOS 내장 TTS (무료)

**TTS 엔진**: AVSpeechSynthesizer (macOS 내장, 완전 무료, 오프라인)
**대화 스크립트**: 기존 LLM 폴백 체인 활용 (OpenRouter → yTeaser → A.X 4.0 → Gemini)

#### 3-1. 데이터 모델 + 서비스

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-520 | **PodcastService.swift 생성** — 팟캐스트 생성 서비스 (actor) | high | completed | ✅ |
| T-520a | **PodcastScript 모델** — PodcastSegment, PodcastResult 모델 정의 | high | completed | ✅ |
| T-521 | **AI 대화 스크립트 생성 프롬프트** — 2인 대화 (진행자A/B), 15~25 세그먼트 | high | completed | ✅ |
| T-522 | **TTSService 생성** — AVSpeechSynthesizer 래퍼, 한국어 음성 선택 | high | completed | ✅ |

#### 3-2. 오디오 생성 + 저장

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-523 | **오디오 파일 저장 로직** — `~/Documents/TubeKeep/Podcasts/{videoId}/` | high | completed | ✅ |
| T-524 | **DB에 podcast_path 저장** — DatabaseManager.updatePodcastPath() | high | completed | ✅ |

#### 3-3. UI 통합

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-525 | **요약 팝업에 팟캐스트 컨트롤 추가** — 재생/일시정지/정지 버튼 + 진행 바 | medium | completed | ✅ |
| T-526 | **컨텍스트 메뉴 팟캐스트 항목** — 팟캐스트 만들기/듣기/삭제 | medium | completed | ✅ |
| T-527 | **LibraryReducer 팟캐스트 액션** — generatePodcast/playPodcast/deletePodcast | high | completed | ✅ |

#### 3-4. 마무리

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-528 | **팟캐스트 파일 정리** — 삭제 시 DB + 디렉토리 삭제 | medium | completed | ✅ |
| T-529 | **Info.plist 버전 2.5.2** | medium | completed | ✅ |

### 챕터 4: 트랜스크립트 Q&A (v2.5.3)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-530 | **QAService.swift 생성** — Q&A 서비스 | high | completed | ✅ |
| T-531 | **qna_history 테이블 생성** | high | completed | ✅ |
| T-532 | **Q&A 프롬프트 설계** | high | completed | ✅ |
| T-533 | **QAView UI** | high | completed | ✅ |
| T-534 | **LibraryReducer Q&A 액션** | medium | completed | ✅ |
| T-535 | **Q&A 히스토리 저장/로드** | medium | completed | ✅ |
| T-536 | **타임스탬프 클릭 → 재생 위치 이동** | medium | completed | ✅ |
| T-537 | **Info.plist 버전 2.5.3** | medium | completed | ✅ |

### 챕터 5: 마인드맵 생성 (v2.5.4)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-540 | **MindmapNode 모델 생성** | high | completed | ✅ |
| T-541 | **MindmapService.swift 생성** | high | completed | ✅ |
| T-542 | **마인드맵 생성 프롬프트** | high | completed | ✅ |
| T-543 | **DB에 마인드맵 저장** | high | completed | ✅ |
| T-544 | **MindmapView UI** | medium | completed | ✅ |
| T-545 | **마인드맵 노드 확장/축소** | low | completed | ✅ |
| T-546 | **마인드맵 이미지 내보내기** | low | cancelled | 패스 |
| T-547 | **Info.plist 버전 2.5.4** | medium | completed | ✅ |

### 챕터 6: UI 통합 + 챕터 표시 (v2.5.5)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-550 | **LibraryGridView 챕터 표시** | high | completed | ✅ (v2.5.1에서 완료) |
| T-551 | **LibraryListView 챕터 표시** | high | completed | ✅ (v2.5.1에서 완료) |
| T-552 | **액션 메뉴 통합 (3→1 "AI 기능")** | high | completed | ✅ |
| T-553 | **AIWindowView 좌우 split 레이아웃** | medium | completed | ✅ |
| T-554 | **팟캐스트 시간 왼쪽 표시** | medium | completed | ✅ |
| T-555 | **다크모드 오버레이 + 자동 포커스 방지** | medium | completed | ✅ |
| T-556 | **Info.plist 버전 2.5.5** | medium | completed | ✅ |

### 챕터 7: 마이그레이션 + 테스트 (v2.5.6)

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-560 | **DatabaseManager 마이그레이션 로직** | high | completed | 배포 전 검증 |
| T-561 | **기존 데이터 동기화 (summary→DB)** | high | completed | 배포 전 검증 |
| T-562 | **SwiftData 새 속성 마이그레이션** | high | completed | 배포 전 검증 |
| T-563 | **전체 기능 테스트** | high | completed | TC-5-63 자동화 완료, 수동 패스 |
| T-564 | **빌드 검증 (0 warnings)** | high | completed | 76 tests ✅ |
| T-565 | **테스트 명세서 작성** | medium | completed | docs/tests/v2.5.6.md |
| T-566 | **PLAN.md 업데이트** | medium | completed | |
| T-567 | **TODO.md 업데이트** | medium | completed | |
| T-568 | **Info.plist 버전 2.5.6** | medium | completed | |

## v2.6.0 — 자체 비디오 플레이어 + 플레이어 모드 설정 (2026-07-20) 🚀

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-600 | **PlayerItem.swift — 모델 생성** | high | completed | |
| T-601 | **NSPlayerView.swift — AVPlayerView wrapper** | high | completed | |
| T-602 | **SubtitleOverlay.swift — 자막 오버레이** | high | completed | |
| T-603 | **SubtitlePanel.swift — 자막 패널** | high | completed | |
| T-604 | **PlayerReducer.swift — TCA reducer** | high | completed | |
| T-605 | **PlayerView.swift — 최종 view + toolbar** | high | completed | |
| T-606 | **Settings: PlayerMode enum + field** | high | completed | |
| T-607 | **SettingsReducer: playerMode state/action** | high | completed | |
| T-608 | **SettingsView: 시스템 탭 picker** | high | completed | |
| T-609 | **Constants: openPlayerWindowNotification** | high | completed | |
| T-610 | **AppDelegate: playerWindow + 핸들러** | high | completed | |
| T-611 | **LibraryReducer: openFile/openSelected 분기** | high | completed | |
| T-612 | **YouTubeDLService: fetchStreamingURL** | high | completed | |
| T-613 | **DiscoverView: 미리보기 버튼** | high | completed | |
| T-614 | **Info.plist 버전 2.6.0** | medium | completed | |
| T-615 | **문서 업데이트 (CHANGELOG, TODO, PLAN)** | medium | completed | |
| T-616 | **빌드 검증** | high | completed | |
| T-617 | **테스트 계획서 작성** | high | completed | |

## v2.6.1 — H.264 우선 다운로드 + 트랜스코딩 캐시 + 호버 컨트롤 (2026-07-20) 🏁

| ID | 작업 | 우선순위 | 상태 | 테스트 |
|----|------|---------|------|--------|
| T-618 | **H.264 코덱 필터** — `[ext=mp4][vcodec^=avc1]` 포맷 최우선 선택 | high | completed | |
| T-619 | **기본 해상도 360p** — Constants.defaultResolution 480→360 | high | completed | |
| T-620 | **트랜스코딩 캐시** — transcodedCacheDirectory + SHA256 키 + 캐시 히트/미스 | high | completed | |
| T-621 | **변환 진행률 + ETA** — ffmpeg -progress pipe:1, out_time_us/speed 파싱 | high | completed | |
| T-622 | **자막 언어 우선순위** — `.sorted`로 ko 먼저 배치 | medium | completed | |
| T-623 | **자막 오버레이 기본값 false** — 싱글클릭 토글 (더블클릭 전체화면 유지) | medium | completed | |
| T-624 | **자막 패널 자동 스크롤 버그 수정** — onChange를 ScrollViewReader 레벨로 통합 | medium | completed | |
| T-625 | **플레이어 컨트롤 호버 오버레이** — ZStack 하단 + 3초 auto-hide + onContinuousHover | high | completed | |
| T-626 | **PlayerReducer 확장** — conversionProgress/ETA State + Action | high | completed | |
| T-627 | **전체화면/윈도우 수정** — WindowAccessor, toggleFullscreen, styleMask, collectionBehavior | high | completed | |
| T-628 | **릴리스 v2.6.1 (build 9)** — Info.plist + CHANGELOG | high | completed | |
| T-629 | **문서 업데이트** — PRD/DESIGN/PLAN/TODO/AGENTS | medium | completed | |
| T-630 | **after_move:filepath 경로 검증 fallback** | high | completed | |
| T-631 | **DownloadManager H.264 필터 추가** | high | completed | |
| T-632 | **메뉴바 드롭메뉴 NSView 기반 전환** — attributedTitle → makeQueueMenuItemView | medium | completed | |
| T-633 | **timestamp() DateFormatter 스레드 안전성** — 정적 Formatter + OSAllocatedUnfairLock | high | completed | |
| T-634 | **DownloadManager data race 수정** — ManagerState + stateLock(OSAllocatedUnfairLock) | high | completed | |
| T-635 | **드롭메뉴 NSView 기반 전환** — attributedTitle → makeQueueMenuItemView | high | completed | |
| T-636 | **드롭메뉴 좌우 여백 일치** — menuLeftPadding 19, menuRightPadding 14 | medium | completed | |
| T-637 | **드롭메뉴 너비 축소** — 280→187 | medium | completed | |
| T-638 | **Mock 테스트 target 누락 수정** — target = self 추가 | high | completed | |
| T-639 | **TTSEngine 기본값 변경** — .apple → .edgeTTS (3군데) | medium | completed | |
| T-640 | **문서 업데이트** — CHANGELOG/AGENTS/PLAN/TODO | medium | completed | |

## v2.7.0 — 시스템 언어 + 쿠키 인증 + Whisper AI 자막 + 프리셋 + 히스토리 (2026-07-20) 🔄

### H-2: 시스템 언어 기반 동적 전환 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-700 | **LanguageService 생성** — systemLanguageCode, subtitleLanguages, ttsVoice, appleTTSLanguage, aiPromptLanguage | high | completed | Helpers/LanguageService.swift |
| T-701 | **Settings.subtitleLanguageOverride** — 옵션 + SettingsView picker | medium | completed | |
| T-701a | **DownloadManager.swift** — `--sub-langs` LanguageService 교체 | high | completed | |
| T-701b | **YouTubeDLService.swift** — `--sub-langs` 교체 | high | completed | |
| T-701c | **PlayerReducer.swift** — `--sub-langs` 교체 (시스템 언어 우선) | high | completed | |
| T-701d | **SummarizationService.swift** — `--sub-langs` 교체 | high | completed | |
| T-701e | **LibraryReducer.swift** — `--sub-langs` 교체 | high | completed | |
| T-701f | **TTSService.swift** — AVSpeechSynthesisVoice(language:) 교체 | medium | completed | |
| T-701g | **EdgeTTSClient.swift** — 음성/언어 교체 | medium | completed | LanguageService.ttsVoice(for:) 적용 |
| T-701h | **PodcastService.swift** — 하드코딩 음성 교체 | medium | completed | |

### H-1: 브라우저 쿠키 인증 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-702 | **Settings.cookiesFromBrowser** — 필드 + Picker UI + Common args 반영 | high | completed | |

### H-6: 다운로드 히스토리 (DB) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-703 | **DatabaseManager download_history 테이블** — CREATE + CRUD + DownloadHistoryItem 모델 | high | completed | |
| T-703b | **AppReducer.downloadCompleted** — 히스토리 저장 로직 | high | completed | |
| T-704 | **HistoryView** — 테이블 뷰 + 검색 + 필터 + 우클릭 메뉴 | medium | completed | |
| T-704a | **LibrarySidebarView** — "다운로드 히스토리" 항목 추가 | medium | completed | |

### H-5: 다운로드 프리셋 / Smart Mode ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-705 | **DownloadPreset 모델 + Settings 통합** — presets, activePresetId, smartMode | high | completed | DownloadPreset.swift + Settings 3개 필드 |
| T-706 | **SettingsView 프리셋 편집 UI** — 추가/편집/삭제 | medium | completed | downloads 탭: preset/Smart Mode 행 + 목록 + 삭제 |
| T-707 | **Smart Mode 다운로드 플로우** — 정보 조회 후 프리셋 자동 적용 → 큐 추가 | high | completed | AppReducer.infoResponse에서 activePreset 적용 |

### H-3: AI 자막 생성 (Whisper) ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-708 | **Whisper.cpp CLI 번들링** — BundledLibraryManager에 등록 | high | completed | WhisperKit SPM 대신 whisper.cpp CLI 방식 |
| T-709 | **WhisperService** — model download/audio extract/transcribe | high | completed | @unchecked Sendable class, whisper.cpp CLI |
| T-710 | **설정 UI + Settings 필드** — enableWhisperTranscription, whisperModelSize | high | completed | SettingsView Whisper 섹션 |
| T-711a | **PlayerReducer Whisper fallback** | high | completed | transcribeWithWhisper 액션 + SubtitlePanel UI |
| T-711b | **SummarizationService Whisper fallback** | high | completed | fetchTranscript: yt-dlp 실패 → Whisper fallback |
| T-710c | **토스트 알림 독립 컴포넌트** — ToastComponents.swift | medium | completed | ToastMessage/ToastBanner/ToastOverlay + MainView/DownloadQueueView 리팩토링 |

### 문서

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-712 | **문서 업데이트** — CHANGELOG/PLAN/TODO/DESIGN/tests/v2.7.0.md | medium | completed |

## v2.7.1 — 디버그 로그 UI 개선 + 단축키

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-800 | **DebugLogView 자동스크롤 토글** — checkbox → `arrow.down.to.line` image toggle | medium | completed | 자동스크롤 토글 버튼 모양 변경 |
| T-801 | **DebugLogView 하단 버튼 크기 정규화** — `.controlSize(.small)` 제거 | low | completed | 4개 버튼 크기 통일 |
| T-802 | **Cmd+D 단축키 - 디버그 로그** — keyMonitor 감지 + openDebugLogWindow | medium | completed | AppDelegate.swift |
| T-803 | **Cmd+, keyCode 수정** — Space(49) → Comma(43) | high | completed | AppDelegate.swift keyCode 버그 |
| T-804 | **툴바 드롭다운 통합** — 3개 툴바 버튼 → `Menu("영상 다운로드")` | medium | completed | MainView.swift |

## v2.7.2 — 설정 재구성 + 재생 속도 개선

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-805 | **설정 4탭 → 5탭** — 다운로드·저장·알림 신규·시스템·AI | high | completed | SettingsView.swift + SettingsTab enum |
| T-806 | **"채널 업데이트 알림" → "채널 업데이트 확인"** — OFF 시 완전 중단 | high | completed | ChannelUpdateService.swift Combine observer |
| T-807 | **상태바 큐 항목 비활성화 수정** — `action:nil` → `#selector(queueItemNoop)` | high | completed | StatusBarManager.swift |
| T-808 | **채널 체크박스 선택 미초기화** — `addSelectedToQueue()`에서 `selectedIDs` 누락 | high | completed | ChannelContentView.swift |
| T-809 | **첫 재생 지연 단축** — ffprobe → AVURLAsset.loadTracks | high | completed | PlayerView.swift needsTranscoding() |
| T-810 | **codecCache UserDefaults 저장** — 앱 재시작에도 코덱 캐시 유지 | medium | completed | |
| T-811 | **포맷 선택 lower-first 알고리즘** — `Format.best()` exact→lower→higher | high | completed | Format.swift |
| T-812 | **BatchDownloadView 설정 동기화** — selectedResolution 초기값 settings.defaultResolution | medium | completed | |
| T-813 | **ChannelContentView 설정 동기화** — presetResolution 초기값 settings.defaultResolution | medium | completed | |
| T-814 | **상태바 정렬 통일** — idle/완료/상태표시 모두 .right 정렬 | low | completed | |

## v2.7.3 — DMG 배포 + GitHub Releases ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-820 | **DMG 생성 스크립트** — Tools/create_dmg.sh (Applications symlink + Finder 레이아웃) | high | completed | |
| T-821 | **Makefile release 개선** — 빌드→DMG→gh release 통합 | high | completed | |
| T-822 | **build_and_run.sh --no-launch** — release 빌드용 플래그 | medium | completed | |
| T-823 | **DebugLogManager release 호환성** — #if DEBUG 원인으로 release 빌드 실패 수정 | high | completed | |

## v2.7.4 — 코드 서명 + Notarization ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-830 | **Tools/codesign.sh** — Developer ID 서명 + Notarization + Staple + DMG 서명 | high | completed | |
| T-831 | **Makefile codesign/notarize/sign-only/release-signed** 타겟 | medium | completed | |

## v2.7.5 — 자체 업데이트 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-840 | **UpdateChecker.swift** — appcast.json 기반 버전 체크 + 건너뛰기 | high | completed | |
| T-841 | **AppDelegate 업데이트 알림** — 시작 3초 후 체크 → alert | medium | completed | |
| T-842 | **appcast.json** — 최신 버전 메타데이터 (GitHub raw) | medium | completed | |

## v2.7.7 — 오디오 누락 버그 수정 + DebugPanel v1.7 ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-860 | **parseFormats combined 우선** — formatMap dedup에서 combined 보호 | high | completed | YouTubeDLService.swift |
| T-861 | **bestaudio[ext=m4a] → bestaudio** — Opus/webm 오디오 배제 문제 수정 | high | completed | YouTubeDLService.swift + DownloadManager.swift |
| T-862 | **채널 다운로더 오디오 누락 근본 수정** — 복합 포맷 선택자 `/best` 분기 래핑 방지 | high | completed | DownloadManager.swift + YouTubeDLService.swift |
| T-863 | **DebugPanel v1.7 전환** — DebugLogLevel 7종, DebugLogEntry, push/clear/formatForAgent | high | completed | DebugLogManager.swift |
| T-864 | **DebugLogView v1.7** — 📌 자동 스크롤, 레벨별 색상, 줄 선택, 복사 | high | completed | DebugLogView.swift |
| T-865 | **NSWindow v1.7 표준** — 600×320 중앙, .floating+100, isReleasedWhenClosed=false | high | completed | AppDelegate.swift |
| T-866 | **Package.swift .define("DEBUG")** — release 빌드 DebugPanel 컴파일 타임 제거 | high | completed | Package.swift |
| T-867 | **build_and_run.sh v1.7 디스패처** — scripts/build-macos.sh 분리, 멀티 플랫폼 | medium | completed | build_and_run.sh |
| T-868 | **Mock/DEBUG 코드 전면 제거** — 모든 뷰/리듀서/액션에서 mock 관련 코드 삭제 | high | completed | 8개 파일 |
| T-869 | **beads/AGENTS.md/codex 정리** — 불필요 파일 삭제, AGENTS.md 전역 설치 | medium | completed | |

## v2.7.6 — 랜딩 페이지 + Buy Me a Coffee ✅

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-850 | **GitHub Pages 랜딩 페이지** — docs/index.html + style.css + app-icon.png | high | completed | |
| T-851 | **Buy Me a Coffee** — 메뉴바 "☕ 후원하기" 항목 + AppDelegate 핸들러 (borasarang) | medium | completed | |

## v3.1 — 유틸리티 기능 5종 (클립/채널 자동/단축키/자막 자동/디스크 정리) 🚧

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1040 | **클립 저장** — ClipItem DB + ClipService(ffmpeg 컷) + PlayerView "클립 저장" 버튼 | high | completed | PLAN_v3.1_macos.md |
| T-1041 | **클립 카테고리** — 사이드바 + 그리드 목록 + 재생/삭제/Finder | high | completed | ClipView.swift |
| T-1042 | **채널 자동 다운로드 v1** — 채널별 토글 + 신규 영상 enqueue | medium | completed | ChannelModels.swift + ChannelContentView.swift + ChannelUpdateService.swift |
| T-1043 | **전역 단축키** — 다운로더 3종 + 설정 커스텀 UI | medium | completed | GlobalShortcutService.swift + SettingsSystemTab.swift |
| T-1044 | **유휴 시 자막 자동 다운로드** — idleTimer + 순차 처리 + 상태바 + 설정 옵션 | medium | completed | IdleSubtitleService.swift + SettingsNotificationsTab.swift |
| T-1045 | **디스크 정리 뷰** — 정렬/필터/일괄 삭제 | medium | completed | DiskCleanupView.swift |
| T-1046 | **v3.1 릴리즈** — 버전 3.1.0(build 21) + CHANGELOG | high | completed | Info.plist + CHANGELOG + tag v3.1.0 |

## v3.1.1 — 정밀 분석 버그 수정 (11파일) 🚧

> 전체 소스 정밀 분석에서 확인된 핵심 버그 10종 수정. 빌드 + `swift test` 76/76 통과.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1050 | **DB 버그 3종** — `channel_name` 컬럼명 수정, `subtitles_json` ALTER 중복 방지, `qna_history` NULL 크래시 방어 | high | done | DatabaseManager.swift |
| T-1051 | **Settings decodeIfPresent 전환** — 저장 키 누락 시 전체 리셋 방지 | high | done | Settings.swift init(from:) |
| T-1052 | **SwiftDataMigration 실패 시 재시도** — 성공/실패 Bool 반환, 실패 시 완료 플래그 미설정 | high | done | SwiftDataMigration.swift |
| T-1053 | **appGroupSuiteName 수정** — 실제 entitlements 값 `group.com.tubekeep`으로 | high | done | Constants.swift:5 |
| T-1054 | **항목 삭제 시 연관 데이터 정리** — AI 데이터/QnA/FTS/썸네일 purge | medium | done | LibraryCacheService.removeItem(s) + purgeAssociatedData |
| T-1055 | **ProcessRegistry deadlock 해소** — lock 밖에서 terminationHandler 설정 | high | done | ProcessRegistry.swift |
| T-1056 | **ProcessRunner 파이프 deadlock/취소/데이터레이스** — stdout/stderr drain, SIGKILL 취소, MutableData+NSLock | high | done | ProcessRunner.swift 재작성 |
| T-1057 | **DownloadManager 취소 상태 + 성공 오판 방지** — canceledItems, 취소/일시정지 시 후처리 생략 | high | done | DownloadManager.swift |
| T-1058 | **YouTubeDLService stderr 범위 크래시** — `data[offset...]` → `dropFirst` | medium | done | YouTubeDLService.swift 2곳 |
| T-1059 | **IdleSubtitleService 메인 블록 + 취소 경합** — waitUntilExit → 폴링, 취소 후 후속 처리 가드 | high | done | IdleSubtitleService.swift |
| T-1060 | **ClipService 파일명 충돌 + 메인 블록 + 취소 불가** — UUID 접미사, 썸네일 async, runFFmpeg 취소 | high | done | ClipService.swift |

## v3.2 — 자주 쓰는 흐름 자동화 (이어보기/유휴 AI 배치/채널 프리셋/중복 방지/재생목록/큐 정렬) 🚧

> PLAN_v3.2_macos.md. "받고 → 보고 → 정리" 반복 작업 자동화 6종.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1070 | **PLAN_v3.2 + TODO 등록** | high | done | docs/plans/PLAN_v3.2_macos.md |
| T-1071 | **이어보기** — lastPlaybackPosition 저장 + 배지 + 재개 | high | done | 빌드+테스트 76/76 |
| T-1072 | **유휴 AI 배치** — 자막 후 요약/태깅/팟캐스트 자동 | high | done | Settings idleAutoSummary/Podcast + runAutoAI |
| T-1073 | **채널 자동 다운로드 v2** — 채널별 프리셋(해상도/MP3/자막/개수) | medium | done | ChannelAutoSettings + dailyLimit |
| T-1074 | **중복 다운로드 방지** — 조회 시 중복 표시 + 스킵 | medium | done | isDuplicate 배지 + 이력 기반 스킵 |
| T-1075 | **재생목록 감시** — 재생목록 구독 + 신규 자동 다운로드 | medium | done | SubscribedPlaylist + 사이드바 UI |
| T-1076 | **큐 드래그 재정렬** — 대기열 순서 변경 + 영속 | medium | done | List onMove + setItems |
| T-1077 | **핵심 기능 자동화 테스트** — test-core.sh + 수동 체크리스트 | medium | done | scripts/test-core.sh + docs/tests/manual-checklist.md |
| T-1078 | **디버그 로그창 고도화** — 레벨 픽커 + 검색 + 카운트 (AGENTS 19장 표준) | medium | done | DebugLogView.swift + DebugLogManager.swift |
| T-1079 | **설정 UI/UX 개편** — 탭 7개 세분화(채널/자동화 신규) + 숨겨진 설정 노출 + 창 확대 | medium | done | Settings*.swift + SettingsTab + AppReducer + AppDelegate |
| T-1080 | **디자인 시스템 L1·L2** — DesignTokens(색/폰트/간격) + 공통 컴포넌트(SearchField/StatusBadge/EmptyState/ErrorBanner/SectionHeader) | medium | done | Theme/DesignTokens.swift + Components/ (시스템 블루 유지) |
| T-1081 | **복합 컴포넌트 + 라이브러리 적용** — SortBar/SelectionBar + Grid/List/DiskCleanup 중복 제거 | medium | done | Components/SortBar.swift, SelectionBar.swift |
| T-1082 | **다운로드/검색 적용** — DownloadQueue WaveProgress 토큰화 + 사이드바 검색 AppSearchField + ErrorBanner 적용(Home/Channel) | medium | done | DownloadQueueView.swift, LibrarySidebarView.swift, HomeView.swift |
| T-1083 | **DESIGN_SYSTEM.md + 검증/커밋** — 디자인 시스템 문서화 + 빌드/테스트 + 세션 로그 | medium | done | docs/DESIGN_SYSTEM.md |

## v3.3 — 비슷한 영상 검색 (Similar Videos) 🚧

> PLAN_v3.3_similar-macos.md. 재생 중 영상 → AI 검색어 생성 → yt-dlp ytsearch로 실제 유튜브 유사 영상 검색.

| ID | 작업 | 우선순위 | 상태 | 비고 |
|----|------|---------|------|------|
| T-1084 | **SimilarVideoService 신규** — AI 검색어 생성(OpenRouter→Gemini→규칙 폴백) + UserDefaults 캐시(7일) + 병렬 검색·병합 | high | ✅ done | 2026-08-23 코드 확인(Services/SimilarVideoService.swift) |
| T-1085 | **PlayerReducer 확장** — similarVideos/isLoadingSimilar/similarError/showSimilarVideos 상태 + Action 5종 | high | ✅ done | 2026-08-23 코드 확인(loadSimilarVideos 등) |
| T-1086 | **PlayerView UI** — 툴바 버튼 + SimilarVideosPanel(로딩/오류·재시도/빈 상태, 클릭→재생 전환) | high | ✅ done | 2026-08-23 코드 확인(similarVideosPanel) |
| T-1087 | **검증** — make build + swift test 76 + 실제 재생 수동 확인 | high | ✅ done | 2026-08-23 사용자 실동작 테스트 통과 |


