# CHANGELOG

## v1.2.0 (2026-07-16) — 채널 업데이트 알림 개선 + 디스크 사용량 표시

### New Features
- **채널 업데이트 알림 (T-114)**: 30분 타이머로 채널 최신 영상 감지, `channelsNewVideos`/`channelsSeenVideoIds` UserDefaults 키로 신규/확인 영상 추적
  - 뱃지 클릭 → 채널 다운로더 창 오픈 (첫 새 영상 채널 자동 선택)
  - `seenVideoIds` 도입: 사용자가 확인(채널 선택/새로고침)한 영상은 `seenIds`로 이동, 다운로드 안 해도 재감지 안 됨
  - 상태바 진행률: "업데이트 확인 중 (N/M)" 표시
  - DEBUG 로그: `channelLogManager` → `libraryLogManager`로 변경 (메인 창에 출력)
  - `ChannelRow`: 새 영상 채널에 빨간 ● 배지
  - `ChannelContentView.channelHeader`: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 배너
- **디스크 사용량**: LibrarySidebarView 하단에 `[폴더] Finder에서 보기  12.3 GB  ↻` 표시
  - `LibraryCacheService.calculateDiskUsage()` — `storageDirectory` + 캐시 디렉토리 합산
  - 앱 실행 시, 다운로드 완료 시, 항목 삭제 시, ↻ 버튼 클릭 시 재계산
- **저장 폴더 기본값 변경**: `~/Downloads` → `~/Documents/TubeKeep` (사용자 실수 삭제 방지)
- **변수명 리팩토링**: `outputDirectory` → `storageDirectory` (코드 전체 일괄 변경)
- **UI 텍스트 변경**: "출력 폴더" → "저장 폴더" (설정 창, 다운로드 큐)
- **JSON 키 호환성 유지**: `Settings.CodingKeys`로 `"outputDirectory"` 키 마이그레이션 없이 호환

### Bug Fixes
- **statusBar badge 자동 리셋 제거**: 뱃지가 10초 후 사라지지 않고 사용자 클릭 시까지 유지
- **openVideoDownloaderWindow**: `MainView` → `VideoDownloadView`로 수정 (잘못된 뷰 참조)
- **자막 배지 미표시**: 두 가지 원인 수정
  - Migration 코드가 자막 파일(`.vtt`/`.srt`)을 비디오로 잘못 인식해 `filePath`를 `.ko.vtt`로 저장하는 버그 — 확장자가 비디오인지 확인 후 강제 재설정
  - 비디오 파일(NFC)과 자막 파일(NFD) 간 Unicode 정규화 불일치로 `hasSubtitles()`가 자막 파일을 찾지 못하는 버그 — `contentsOfDirectory` + ASCII `hasSuffix` 매칭으로 NFC/NFD 차이에 영향받지 않음

### Migration
- **저장 폴더 변경 시 LibraryItem.filePath 자동 마이그레이션**: `LibraryCacheService.loadItems()`에서 `filePath`가 실제 파일이 존재하지 않으면 현재 `channelStorageDirectory`에서 video ID로 파일을 찾아 경로 자동 수정
  - 저장 폴더를 변경하고 기존 파일들을 직접 옮겨도 라이브러리 항목이 정상 동작 (삭제, Finder 열기 등)
  - `LibraryItem.filePath`를 `let` → `var`로 변경하여 런타임 수정 가능

### Housekeeping
- 모든 빌드 경고 해결 (Sendable captures, MainActor.run unused result, keypath inference)

## v1.1.0 (2026-07-16) — 설정 창 분리 + 뷰 이름 정리 + 이미지 캐싱 + 라이브러리 편의성

### Breaking Changes
- **앱 이름 변경**: `VideoDownloader` → **TubeKeep**
- **번들 ID**: `com.mdownload.videodownloader` → `com.tubekeep`
- **URL Scheme**: `mdownload://` → `tubekeep://`
- **설치 경로**: `~/Applications/VideoDownloader.app` → `~/Applications/TubeKeep.app`
- **UserDefaults Suite**: `com.mdownload.videodownloader.shared` → `com.tubekeep.shared`

### Image Caching
- **중앙 캐시 서비스 통일**: 모든 썸네일/아바타 로딩이 `LibraryCacheService`(NSCache + 디스크) 경유, 오프라인에서도 표시
- **캐시 디렉토리 수정**: `~/Library/Caches/com.mdownload.library/` → `com.tubekeep/` (리브랜딩 누락분) + 기존 캐시 자동 마이그레이션
- **AsyncImage 제거 (5개 뷰)**: 모든 `AsyncImage`를 `CachedThumbnailView`/`CachedAvatarView`로 교체
  - `HomeView`, `BatchDownloadView`, `DownloadQueueView`, `PlaylistSelectionView`, `ChannelContentView`
- **중복 뷰 제거**: `ChannelContentView` 내 private `CachedAvatarView`/`CachedThumbnailView` 삭제 → `Views/CachedImageViews.swift` 공유 뷰로 통일
- **LibrarySidebarView 아바타 버그 수정**: 비디오 `thumbnailURL`을 아바타로 잘못 사용하던 코드 제거, 캐시/플레이스홀더만 사용

### New Features
- **설정 창 분리 (⌘,)**: `AppDelegate.openSettingsWindow()`로 NSWindow 직접 관리, `TubeKeepApp`은 빈 Scene, 메뉴바 "설정..." + ⌘, 단축키 지원
- **뷰 이름 정리**: `MainView`(영상 다운로더) → `VideoDownloadView`, `LibraryView` → `MainView` (파일명/구조체명/참조 전체)
- **영상 다운로더에서 설정 영역 완전 제거**: `VideoDownloadView` 하단 `SettingsView` 삭제
- **UserDefaults 직접 읽기 → 공유 Store 참조**: `HomeReducer`, `DownloadQueueReducer`, `DownloadManager` 3곳
- **alwaysOnTop 비활성화**: 설정 창에서 회색 처리 + "영상 다운로더 창에서만 사용 가능" 안내
- **설정 창 크기 고정**: 가로 480px 고정, 세로 580px (contentMin/MaxSize)
- **NSUserNotification → UNUserNotificationCenter**: deprecated 해결, 앱 실행 시 권한 요청
- **라이브러리 앱 분리 → 단일 앱 복원**: 단일 바이너리 → `VideoDownloader.app` + `LibraryDownloader.app` → 단일 `TubeKeep.app`으로 통합
- **크로스 프로세스 통신 제거**: `DistributedNotificationCenter` + `NSRunningApplication.activate` 제거, `openMainWindow` 직접 호출
- **데이터 공유**: `UserDefaults(suiteName:)`으로 라이브러리 아이템 앱 간 동기화 + 기존 데이터 자동 마이그레이션
- **언어 지원**: `Constants.youtubeExtractorArgs` — 시스템 언어 기반 yt-dlp `--extractor-args youtube:lang=XX`
- **DEBUG Mock 테스트**: "상태바 테스트" + "채널 업데이트" 서브메뉴
- **채널 업데이트 알림 개선 (T-114)**:
  - 새 영상 ID를 `UserDefaults("channelsNewVideos")`에 채널별 저장 → 상태바 뱃지 자동 리셋 제거 (클릭 시까지 유지)
  - 뱃지 클릭 → 채널 다운로더 창 (첫 새 영상 채널 자동 선택)
  - `ChannelRow`: 새 영상 채널 빨간 ● 배지 (아바타 우상단)
  - `ChannelContentView.channelHeader`: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 오렌지 배너
  - 채널 선택 시 `ChannelDownloadCache.saveSeenVideoIds`로 newIds를 seenIds로 이동 → 다운로드 안 해도 재감지 안 됨
  - `channelsSeenVideoIds` 도입 (UserDefaults): 확인한 영상은 다음 체크에서 제외
  - 다운로드 완료 시 `removeSeenVideoIds` 호출 (seenIds 정리)
  - 체크 진행률: 상태바 `"업데이트 확인 중 (N/M)"` 표시
  - 체크 DEBUG 로그: 채널 다운로더 창 `channelLogManager`에 출력
  - DEBUG "채널 업데이트" → 실제 `checkChannelUpdates` 실행으로 변경
- **라이브러리 재생시간 표시**: `LibraryItem.duration: Int?` + `formatDuration()`; 그리드/목록 뷰에 duration 오버레이
- **라이브러리 채널 영상 인덱스**: `LibraryItem.channelUploadIndex: Int?` — 채널 내 업로드 순서 추적 (001=최신); `LibraryCacheService.updateChannelUploadIndices()`로 자동 업데이트
- **정렬 옵션 확장**: `LibrarySortOrder`에 `indexAsc`/"인덱스순", `indexDesc`/"인덱스 역순" 추가; 채널 선택 시 기본 정렬 = 인덱스 역순
- **UI 인덱스 표시**: 그리드 썸네일 좌하단 `#003` 배지 + 목록 뷰 정보 열에 인덱스 표시

### Bug Fixes
- **채널 @handle 누락**: `fetchAllVideos`에서 handle에 `@` 자동 추가 (저장된 handle 포맷 차이 대응)
- **회원 전용 영상 차단**: `--playlist-items 0` → `--flat-playlist --playlist-end 1` (channel metadata fetch)
- **Short 필터링**: `fetchAllVideos`에서 `webpage_url.contains("/shorts/")` 체크
- **채널 목록 정렬**: 신규 채널이 항상 맨 위에 추가되도록 `insert(at: 0)` (3개 위치 + LibraryReducer)
- **창 전환 지연**: `NSWorkspace.shared.openApplication` → `NSRunningApplication.activate` (실행 중인 앱 직접 활성화)
- **사이드바 채널 아바타 미표시** (v1.0.0): 캐시 미스 시 다운로드 로직 추가
- **필터 전환 시 썸네일 깨짐** (v1.0.0): 불필요한 removeAll 제거
- **채널 새로고침 시 다운로드 체크 누락**: `syncDownloadedIDsFromDisk()`가 호출되지 않아 디스크 파일과 UserDefaults 캐시 불일치; refresh 후 호출 추가
- **macOS 권한 팝업 반복**: `BookmarkManager`(security-scoped bookmark) 도입으로 출력 폴더 접근 권한 1회 획득 후 유지
- **CachedImageViews actor isolation 경고**: `await` 추가로 Swift 6 준수
- **AppDelegate Sendable closure capture 경고**: 로컬 상수 캡처로 수정

### UI Improvements
- **채널 카운트**: `ChannelListView` 하단 `등록된 채널 N개` (아이콘 + 배경)
- **채널 추가 버튼**: `ChannelContentView` empty state에 "채널 추가" 버튼 (`onAddChannel`)
- **자막 다운로드 뱃지**: 썸네일 우측 상단 고정
- **호버 미리보기 위치**: 셀 중앙 기준 왼쪽으로 확장 (`cell.midX - 360`), 하단 기준=셀 상단 → 중앙 (`maxY+5` → `midY`) — 썸네일 우상단 1/4 가림
- **메뉴바 메뉴**: 모든 항목 `target: self` 명시 (Selector 불일치 방지)
- **정보 창**: 새로운 "정보" 메뉴 항목 + AboutView
- **채널 아바타 동그랗게**: `CachedAvatarView`에 `.clipShape(Circle())` 적용; `ChannelListView` 왼쪽 패딩 12px
- **메뉴바 "설정..." 추가**: ⌘, 단축키, AppDelegate 메뉴 재구성

### Housekeeping
- `Sources/MDownload/` → `Sources/TubeKeep/` 디렉토리 리네임
- `Sources/MDownloadCore/` → `Sources/MDownload/` 통합 (단일 모듈)
- `FixedWidthWindowController` 별도 파일로 분리
- **단일 `.app` 복원**: `LibraryDownloader.app` 제거, 단일 `TubeKeep.app`으로 통합
- `DebugLogView`: 각 window에 DEBUG 전용 동작 로그 패널 추가 (자동 스크롤 + 복사 가능)
- `LibraryInfo.plist` 삭제
- `build_and_run.sh`: 앱 이름 `VideoDownloader` → `TubeKeep`, `--clean` 옵션 추가 (기본 增量 빌드)
- `docs/IMAGE_CACHING.md` — 이미지 캐싱 아키텍처 문서 추가
- `CachedImageViews.swift` — 공유 `CachedThumbnailView`/`CachedAvatarView` 뷰 파일 생성
- `BookmarkManager.swift` — security-scoped bookmark 관리 유틸리티 (접근 권한 1회 획득 후 재시작 시 자동 복원)
- 모든 Swift 6 Sendable 경고 수정 (0 warnings)

---

## v1.0.0 (2026-07-14) — Initial Release

### Milestone: 라이브러리 대시보드 (M5) 완료
- LibraryItem 모델 + LibraryReducer (sort/filter/search + viewMode)
- LibraryCacheService (메모리+디스크 썸네일/아바타 캐시)
- LibraryView (HStack: sidebar 200px + content, toolbar)
- LibrarySidebarView (검색, 전체/최근, 채널 목록 + 우클릭)
- LibraryGridView (LazyVGrid, 인피니트스크롤, 좌클릭 NSMenu)
- LibraryListView (LazyVStack, 동일 메뉴)
- EmptyLibraryCell (full-width 안내 + 3개 다운로더 버튼)
- AppDelegate 메뉴/창 분리 (라이브러리=main 자동실행, 다운로더=별도)
- downloadCompleted → library 저장 + race condition 수정

### Bug Fixes
- `-[NSIndirectTaggedPointerString count]` crash → `OSAllocatedUnfairLock`
- 다운로드 개수 불일치 → sequential save+load
- "다운로드" 버튼 잘못된 창 → `openDownloaderWindowNotification`
- 모든 Swift 6 Sendable 경고 수정 (0 warnings)
- 그리드 레이아웃 리사이즈 깨짐 → EmptyLibraryCell 분리
- FixedWidthWindowController dealloc → AppDelegate 프로퍼티 저장
- 사이드바 채널 아바타 미표시 → 캐시 미스 시 다운로드 로직 추가

### UX Improvements
- 메뉴바 "라이브러리" 아래 구분선 추가
- 그리드/목록 뷰모드 전환 (sortBar 우측 토글, UserDefaults 저장)
- 좌클릭 NSMenu (LeftClickMenu, NSViewRepresentable)
- 클립보드 감지 — 라이브러리 창 열려 있어도 다운로더 창 오픈
- 자동 실행 (build_and_run.sh open 추가)
- build/ 디렉토리 gitignore 추가

### Housekeeping
- 사용하지 않는 `queueSaveKey` 상수 제거
- 문서 전용 폴더 `docs/` 생성 및 이동 (AGENTS/PRD/DESIGN/PLAN/TODO)
- Git init + tag v1.0.0
- Release 아카이브: `Releases/v1.0.0/` (VideoDownloader.app + source.zip)
