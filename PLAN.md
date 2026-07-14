# PLAN — 구현 계획 및 진행 상황

## Milestones

| 단계 | 상태 | 설명 |
|------|------|------|
| M1: 메뉴바 + 기본 UI | ✅ 완료 | 메뉴바, 메인창, URL 입력, 조회 |
| M2: 다운로드 엔진 | ✅ 완료 | yt-dlp 연동, 큐 관리, 진행률 |
| M3: 설정 + 사용자 경험 | ✅ 완료 | 설정 UI, 클립보드, 단축키, ETA, 컨텍스트메뉴, 자동재시도, 토스트, 중복검사, 번들링 |
| M4: 채널 다운로더 | ✅ 완료 | 새 창, 좌우 분할, 채널 목록 + 영상 선택 → 일괄 다운로드 |
| M5: 라이브러리 대시보드 | ✅ 완료 | Photos 스타일 메인 창, 그리드/목록 뷰, 검색/필터/정렬, 좌클릭 메뉴 |

---

## 완료된 작업 (Completed)

### M1~M4
- 메뉴바 앱 (SF Symbol + 2줄 텍스트, 88px, 다크모드)
- 우클릭 메뉴 (라이브러리/다운로더/일괄/채널/속도측정/종료)
- 글로벌 단축키 ⌥⌘D
- URL 입력 + 정보 조회 + 포맷 선택 + 자막/오디오
- 다운로드 큐 (WaveProgress, ETA, 토스트, 자동재시도, 중복검사)
- 설정 (동시다운로드/속도제한/출력폴더/해상도/템플릿/알림음/시작프로그램)
- 일괄 다운로더 (다중 URL + 프리셋)
- 채널 다운로더 (전체 flat-playlist, 검색/정렬/인피니트스크롤, 프리셋, 24h 캐시)
- 클립보드 감시 (NSPanel)
- DEBUG Mock 테스트
- 의존성 번들링 (yt-dlp + ffmpeg embedded)

### M5: 라이브러리 대시보드
- [x] LibraryItem 모델 (LibrarySortOrder, LibraryFilterMode, LibraryViewMode)
- [x] LibraryReducer (save/load, sort/filter/search, viewMode UserDefaults)
- [x] LibraryCacheService (메모리+디스크 캐시, 썸네일/아바타)
- [x] LibraryView (HStack sidebar 200px + content, toolbar)
- [x] LibrarySidebarView (검색, 전체/최근, 채널 목록 + 우클릭)
- [x] LibraryGridView (LazyVGrid, 인피니트스크롤, 좌클릭 NSMenu)
- [x] LibraryListView (LazyVStack, 동일 메뉴)
- [x] EmptyLibraryCell (full-width 안내 + 3개 버튼)
- [x] AppDelegate 메뉴/창 분리 (라이브러리=main 자동실행, 다운로더=별도)
- [x] downloadCompleted → library 저장 (race condition 수정: sequential save+load)
- [x] FixedWidthWindowController (가로폭 840 고정)
- [x] 그리드/목록 뷰모드 전환 (sortBar 우측 토글)
- [x] LeftClickMenu (좌클릭 시 좌표 기반 NSMenu)

### 버그 수정
- [x] `-[NSIndirectTaggedPointerString count]` crash — OSAllocatedUnfairLock
- [x] 다운로드 개수 불일치 (3 다운, 2 표시) — sequential save+load
- [x] "다운로드" 버튼이 잘못된 창 오픈 — openDownloaderWindowNotification
- [x] 모든 Swift 6 Sendable 경고 수정 (0 warnings)
- [x] 그리드 레이아웃 리사이즈 깨짐 — EmptyLibraryCell을 LazyVGrid 밖으로
- [x] FixedWidthWindowController dealloc 문제 — AppDelegate 프로퍼티 저장
- [x] 자동 실행 (build_and_run.sh에 open 추가)

---

## 제외된 기능 (Cancelled)

- 큐 검색/정렬
- iCloud 히스토리 동기화
- 자동 업데이트 (Sparkle)
- macOS Notification Center 배너
- 브라우저 확장 (Safari/Chrome)
