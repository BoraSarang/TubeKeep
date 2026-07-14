# TODO — 작업 추적 목록

## 완료된 작업

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

## 취소됨

| ID | 작업 | 사유 |
|----|------|------|
| T-16 | 큐 검색/정렬 | 불필요 |
| T-17 | 속도 측정 URL 안정화 | 기존 fallback 유지 |
| T-18 | iCloud 히스토리 동기화 | 복잡도 대비 효용 낮음 |
| T-19 | 자동 업데이트 (Sparkle) | 범위 외 |
| T-20 | macOS Notification Center 배너 | 메뉴바 badge로 충분 |
| T-21 | 브라우저 확장 | 클립보드 감시로 대체 |
