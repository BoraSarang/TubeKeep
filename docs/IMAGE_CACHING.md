# 이미지 캐싱 아키텍처

## 개요

앱 내 모든 **비디오 썸네일**과 **채널 아바타**는 `LibraryCacheService`(actor)를 통해 **메모리(NSCache) + 디스크** 이중 캐싱된다. 오프라인에서도 이미지가 표시된다.

---

## 캐시 서비스: `LibraryCacheService`

**파일**: `Sources/TubeKeep/Services/LibraryCacheService.swift`

```
LibraryCacheService (actor)
├── thumbCache: NSCache<NSString, NSImage> (countLimit: 500)
├── avatarCache: NSCache<NSString, NSImage> (countLimit: 200)
└── disk: ~/Library/Caches/com.tubekeep/
    ├── thumb_{videoId}.jpg
    └── avatar_{channelId}.jpg
```

### 주요 메서드

| 메서드 | 설명 |
|--------|------|
| `cachedThumbnail(for:)` | 메모리 → 디스크 순서로 캐시 조회 |
| `cacheThumbnail(for:data:)` | 메모리 + 디스크에 저장 |
| `loadThumbnail(from:videoId:)` | 캐시 조회 → 실패 시 URL 다운로드 → 캐시 저장 |
| `cachedAvatar(for:)` | 메모리 → 디스크 순서로 캐시 조회 |
| `cacheAvatar(for:data:)` | 메모리 + 디스크에 저장 |
| `loadAvatar(from:channelId:)` | 캐시 조회 → 실패 시 URL 다운로드 → 캐시 저장 |
| `placeholderAvatar()` | person.circle.fill SF Symbol |
| `placeholderThumbnail()` | film SF Symbol |

---

## 재사용 가능한 캐시 뷰: `Views/CachedImageViews.swift`

### CachedAvatarView
```swift
CachedAvatarView(channelId: String, url: String, size: CGFloat)
```
- 캐시 히트 → `Image(nsImage:)` 즉시 표시
- 캐시 미스 → `ProgressView` + `.task`에서 URLSession 다운로드 → 캐시 저장 → 이미지 표시

### CachedThumbnailView
```swift
CachedThumbnailView(videoId: String, url: String)
```
- 동일한 캐시-우선 로직

---

## 적용된 뷰 목록 (AsyncImage → CachedThumbnailView 교체)

| 뷰 | 파일 | 변경 |
|----|------|------|
| **채널 영상 목록** | `Features/Channel/ChannelContentView.swift` | private 캐시뷰 → 공유 `CachedThumbnailView` |
| **홈(URL 검색 결과)** | `Features/Home/HomeView.swift` | `AsyncImage` → `CachedThumbnailView` |
| **일괄 다운로드** | `Features/BatchDownload/BatchDownloadView.swift` | `AsyncImage` → `CachedThumbnailView` |
| **다운로드 큐** | `Features/DownloadQueue/DownloadQueueView.swift` | `AsyncImage` → `CachedThumbnailView` |
| **재생목록 선택** | `Features/PlaylistSelection/PlaylistSelectionView.swift` | `AsyncImage` → `CachedThumbnailView` |
| **라이브러리 그리드** | `Features/Library/LibraryGridView.swift` | 기존 `LibraryCacheService.loadThumbnail` 사용 (변경 없음) |
| **라이브러리 목록** | `Features/Library/LibraryListView.swift` | 기존 `LibraryCacheService.loadThumbnail` 사용 (변경 없음) |
| **라이브러리 사이드바** | `Features/Library/LibrarySidebarView.swift` | 아바타 URL 버그 수정 (thumbnailURL → cachedAvatar/placeholder) |

---

## 데이터 흐름

```
View 표시
  ↓
CachedThumbnailView / CachedAvatarView
  ↓ loadThumbnail() / loadAvatar()
LibraryCacheService
  ├── NSCache hit? → 즉시 반환 (메모리)
  ├── Disk hit? → NSCache에 저장 후 반환
  └── 모두 miss → URLSession.data() → NSCache + Disk에 저장 → 반환
```

---

## 캐시 디렉토리 마이그레이션

`LibraryCacheService.cacheDir` 계산 시:
1. 새 경로 `~/Library/Caches/com.tubekeep/` 사용
2. 구 경로 `~/Library/Caches/com.mdownload.library/`가 존재하고 새 경로가 없으면 → **이동** (rename)
3. 새 경로가 없으면 생성
