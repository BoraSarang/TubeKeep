# PLAN — 구현 계획 및 진행 상황

## Milestones

| 단계 | 상태 | 설명 |
|------|------|------|
| M1: 메뉴바 + 기본 UI | ✅ 완료 | 메뉴바, 메인창, URL 입력, 조회 |
| M2: 다운로드 엔진 | ✅ 완료 | yt-dlp 연동, 큐 관리, 진행률 |
| M3: 설정 + 사용자 경험 | ✅ 완료 | 설정 UI, 클립보드, 단축키, ETA, 컨텍스트메뉴, 자동재시도, 토스트, 중복검사, 번들링 |
| M4: 채널 다운로더 | ✅ 완료 | 새 창, 좌우 분할, 채널 목록 + 영상 선택 → 일괄 다운로드 |
| M5: 라이브러리 대시보드 | ✅ 완료 | Photos 스타일 메인 창, 그리드/목록 뷰, 검색/필터/정렬, 좌클릭 메뉴 |
| **v1.0.0** | 🏁 **릴리스** | Git tag `v1.0.0`, `~/Applications/VideoDownloader.app` → `TubeKeep.app` |
| **v1.1.0** | 🏁 **전체 완료** | ✅자막 ✅hover툴팁 ✅다중선택삭제 ✅채널순서변경 ✅채널추가버튼 ✅폴더열기 ✅URL Scheme ✅채널업데이트+뱃지클릭+new표시 ✅큐영속성 ✅업로드날짜정렬 ✅단일앱복원 ✅DebugLogView ✅설정창분리(⌘,) ✅뷰이름정리 ✅alwaysOnTop비활성화 ✅설정공유상태화 ✅워닝0 |

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

### v1.1.0 전체 (15건 완료)
- [x] T-118: 사이드바 하단 "채널 추가" 버튼
- [x] T-117: 사이드바 채널 drag-to-reorder
- [x] T-116: 자막 별도 다운로드 (yt-dlp --write-subs)
- [x] T-111: 그리드 셀 hover 썸네일 확대 툴팁 (.popover)
- [x] T-112: 여러 항목 선택 → 일괄 삭제 (Cmd+선택)
- [x] T-110: 다운로드 폴더 열기 버튼 (sidebar 하단)
- [x] T-113: 브라우저 URL Scheme (tubekeep:// 등록 + 처리)
- [x] T-119: 업로드 날짜 필드 + 정렬 확장 (LibraryItem.uploadDate, 2개 정렬 옵션)
- [x] T-115: 다운로드 큐 영속성 (UserDefaults 저장/복원, 재시작 시 active→pending)
- [x] T-114: 채널 구독 업데이트 알림 (30분 주기 체크, UNUserNotification + 뱃지)
  - [x] channelsNewVideos 저장 (UserDefaults, 채널별 새 영상 ID 목록)
  - [x] 뱃지 클릭 → 채널 다운로더 창 (첫 새 영상 채널 자동 선택)
  - [x] 뱃지 자동 리셋 제거 (클릭 시까지 유지)
  - [x] DEBUG 메뉴: "채널 업데이트 (DEBUG)" → 실제 checkChannelUpdates 실행
  - [x] ChannelRow: 새 영상 채널 빨간 ● 배지
  - [x] ChannelContentView.channelHeader: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 배너
  - [x] 채널 선택 시 saveSeenVideoIds + clearNewVideoIds + badgeCount 업데이트
  - [x] channelsSeenVideoIds 도입: 확인한 영상 재감지 방지 (다운로드 안 해도 OK)
  - [x] 다운로드 시 removeSeenVideoIds 호출
  - [x] 체크 진행률 상태바 표시 ("업데이트 확인 중 (N/M)")
  - [x] 체크 DEBUG 로그 (channelLogManager)
- [x] Channel @handle 안전성: fetchAllVideos에서 @ 자동 추가
- [x] 언어 지원: Constants.youtubeExtractorArgs (시스템 언어 기반 yt-dlp --extractor-args)
- [x] 영상 필터링: `@handle/videos` URL로 숏츠 제외 + `availability` 필드로 회원전용 제외
- [x] 채널 신규 항목 insert(at: 0) — 채널 목록 항상 최신순
- [x] Hover 미리보기 위치: cell.midX - 360 (좌측 확장, bottom-right=cell 중앙)
- [x] DEBUG Mock: "상태바 테스트" + "채널 업데이트" 서브메뉴
- [x] 단일 .app 복원: LibraryDownloader.app 제거, 단일 VideoDownloader.app → TubeKeep.app
- [x] DebugLogView: 각 window에 DEBUG 동작 로그 패널 (자동 스크롤 + 복사)

### v1.1.0 추가 (2026-07-15~16 세션)
- [x] 이미지 캐싱 전면 개선: 모든 AsyncImage 제거, CachedThumbnailView/CachedAvatarView 통일, LibrarySidebarView 아바타 버그 수정
- [x] 캐시 디렉토리 경로 수정: com.mdownload.library → com.tubekeep + 마이그레이션
- [x] 라이브러리 재생시간 표시: LibraryItem.duration + formatDuration() + 그리드/목록 UI
- [x] 채널 아바타 동그랗게 + padding
- [x] build_and_run.sh --clean 옵션 추가
- [x] 채널 영상 인덱스 기능: LibraryItem.channelUploadIndex + updateChannelUploadIndices + AppReducer 전달
- [x] LibrarySortOrder indexAsc/indexDesc 추가 + LibraryReducer 정렬 로직 + 채널 선택 기본정렬=인덱스 역순
- [x] 그리드/목록 뷰 인덱스 표시 (#003 배지)
- [x] 새로고침 시 syncDownloadedIDsFromDisk 호출 (디스크-캐시 동기화)
- [x] **설정 창 분리 (⌘,)**: AppDelegate 직접 NSWindow 관리, Settings 씬 미사용
- [x] **뷰 이름 정리**: MainView→VideoDownloadView, LibraryView→MainView (파일명/구조체명/참조 전체)
- [x] **영상 다운로더에서 설정 영역 완전 제거**: VideoDownloadView 하단 SettingsView 삭제
- [x] **메뉴바 "설정..." 추가 (⌘, 단축키)**: AppDelegate 메뉴 재구성
- [x] **UserDefaults 직접 읽기 → 공유 Store 참조로 변경**: HomeReducer, DownloadQueueReducer, DownloadManager 3곳
- [x] **alwaysOnTop 설정 비활성화**: 설정 창에서 비활성/안내 표시 (영상 다운로더 창 전용 속성)
- [x] 설정 창 가로 480px 고정, 세로 580px — contentMin/MaxSize 설정
- [x] NSUserNotification → UNUserNotificationCenter 마이그레이션 (deprecated 해결)
- [x] CachedImageViews actor isolation 경고 수정 — await 추가
- [x] AppDelegate Sendable closure capture 경고 수정 — 로컬 상수 캡처

### 버그 수정
- [x] `-[NSIndirectTaggedPointerString count]` crash — OSAllocatedUnfairLock
- [x] 다운로드 개수 불일치 (3 다운, 2 표시) — sequential save+load
- [x] "다운로드" 버튼이 잘못된 창 오픈 — openDownloaderWindowNotification
- [x] 모든 Swift 6 Sendable 경고 수정 (0 warnings)
- [x] 그리드 레이아웃 리사이즈 깨짐 — EmptyLibraryCell을 LazyVGrid 밖으로
- [x] FixedWidthWindowController dealloc 문제 — AppDelegate 프로퍼티 저장
- [x] 자동 실행 (build_and_run.sh에 open 추가)
- [x] Channel @handle 누락 — fetchAllVideos handle 자동 @ 추가
- [x] 회원 전용 영상 차단 — --playlist-items 0 → --flat-playlist --playlist-end 1
- [x] Short 필터링 — /videos URL + availability 필터 (flat-playlist에서 /shorts/ URL 미출력)
- [x] 단일 .app 복원 (LibraryDownloader.app 제거, DistributedNotification 제거, openMainWindow 직접 호출)
- [x] 동영상 개수: 서버 fetch 시에만 업데이트, 중복 notification 시 덮어쓰기 방지
- [x] refreshChannelInfo videoCount 보존 — fetchChannelInfo가 0 반환해도 기존 count 유지

---

### v1.2.0 — 채널 업데이트 알림 개선 + 디스크 사용량 (2026-07-16)
- [x] channelsSeenVideoIds: 확인한 영상 재감지 방지 (다운로드 안 해도 확인 시 seenIds로 이동)
- [x] 상태바 진행률 ("업데이트 확인 중 (N/M)")
- [x] DEBUG 로그 출력 위치 변경: channelLogManager → libraryLogManager
- [x] StatusBar badge autoReset 제거 (10초 → 클릭 시까지 유지)
- [x] openVideoDownloaderWindow 오류 수정: MainView → VideoDownloadView
- [x] LibraryCacheService.calculateDiskUsage() — outputDirectory + 캐시 디렉토리 합산
- [x] LibraryReducer diskUsageBytes State + calculateDiskUsage/diskUsageUpdated 액션
- [x] AppReducer/LibraryReducer 트리거: downloadCompleted, removeSelected, removeItemsByChannel 시 재계산
- [x] LibrarySidebarView 하단: "Finder에서 보기" + 디스크 사용량 + ↻ 버튼
- [x] formatBytes() — ByteCountFormatter 포맷팅
- [x] 모든 빌드 경고 해결 (0 warnings)
- [x] 저장 폴더 기본값 변경: `~/Downloads` → `~/Documents/TubeKeep`
- [x] 첫 실행 시 `~/Documents/TubeKeep` 자동 생성 (없을 경우)
- [x] 변수명 리팩토링: `outputDirectory` → `storageDirectory` (전체 코드베이스)
- [x] UI 텍스트 변경: "출력 폴더" → "저장 폴더"
- [x] Settings.CodingKeys로 JSON 키 `"outputDirectory"` 하위호환 유지 (마이그레이션 불필요)
- [x] BookmarkManager 키 변경: `outputDirectoryBookmark` → `storageDirectoryBookmark`

## 제외된 기능 (Cancelled)

- 큐 검색/정렬
- iCloud 히스토리 동기화
- 자동 업데이트 (Sparkle)
- macOS Notification Center 배너
- 브라우저 확장 (Safari/Chrome)
