# PLAN v2.8.0 — AI 개인화: 취향 프로필 / 맞춤 추천 / 의미 검색 / 다음 영상 / 주간 다이제스트

> **버전**: v2.8.0 (build 19)
> **목표**: 사용자의 다운로드 데이터를 분석하여 개인화된 경험 제공
> **특성**: 싱글 유저 앱 (모든 데이터 로컬, 다중 사용자 고려 불필요)

---

## 개요

현재 TubeKeep은 YouTube 다운로드 + AI 요약/팟캐스트/Q&A/마인드맵까지 갖췄다.
하지만 모든 AI 기능이 "개별 영상 단위"에 머물러 있다.

v2.8.0에서는 **사용자가 쌓아온 데이터를 cross-video로 분석**하여
개인화된 경험을 제공한다.

---

## 보유 데이터 현황

| 데이터 소스 | 저장소 | 필드 |
|------------|--------|------|
| LibraryItem | SwiftData | id, title, channelId, channelName, tags(10 categories), summary, transcript, chapters, duration, downloadDate, uploadDate, filePath |
| SubscribedChannel | SwiftData | id, name, handle, avatarURL, videoCount |
| video_ai_data | SQLite | video_id, transcript, summary, chapters, mindmap, podcast_path, tags |
| qna_history | SQLite | id, video_id, question, answer, timestamps |
| download_history | SQLite | id, video_id, title, channel_name, format_label, resolution, file_size, downloaded_at |
| Settings | UserDefaults | AI API keys, presets, preferences |

**핵심**: 태깅 10개 카테고리(기술/IT, 음악, 게임, 뉴스, 스포츠, 엔터, 교육, 요리, 여행, 과학)가 모든 LibraryItem에 이미 태깅되어 있음.

---

## 신규 파일 (7개)

| 파일 | 설명 |
|------|------|
| `Models/UserProfile.swift` | 취향 프로필 데이터 모델 |
| `Services/ProfileService.swift` | LibraryItem → 통계 계산 |
| `Services/RecommendationService.swift` | tags/channel 기반 추천 엔진 |
| `Services/SearchService.swift` | SQLite FTS5 의미 검색 |
| `Services/DigestService.swift` | 주간 다이제스트 생성 |
| `Features/Profile/ProfileView.swift` | 취향 대시보드 UI |
| `Features/Profile/ProfileReducer.swift` | 프로필 TCA reducer |

## 수정 파일 (8개)

| 파일 | 변경 내용 |
|------|----------|
| `LibraryReducer.swift` | profile State + Action 추가, sidebarMode 확장 |
| `LibrarySidebarView.swift` | "내 프로필" 네비게이션 항목 추가 |
| `MainView.swift` | profile mode 콘텐츠 전환 |
| `DiscoverView.swift` | "내 취향" 카테고리 + 추천 피드 |
| `PlayerReducer.swift` | `videoDidEnd` Action, recommendations |
| `PlayerView.swift` | 종료 시 추천 오버레이 |
| `AppReducer.swift` | ProfileReducer scope |
| `DatabaseManager.swift` | FTS5 검색 인덱스 |

---

## Step 1: 취향 프로필 (ProfileService + ProfileView)

### UserProfile 모델

```swift
struct UserProfile: Equatable {
    var totalVideos: Int
    var totalChannels: Int
    var totalStorageBytes: Int64
    var categoryDistribution: [(category: String, count: Int, percentage: Double)]
    var topChannels: [(name: String, count: Int)]
    var averageDuration: TimeInterval
    var preferredResolution: Int
    var downloadTimeHistogram: [Int: Int]      // [0:3, 21:12, ...]
    var weeklyDownloadCounts: [String: Int]    // ["기술/IT": 5, "음악": 2]
    var summaryUsageRate: Double               // 요약 사용 비율
}
```

### ProfileService

```swift
enum ProfileService {
    static func calculate(
        items: [LibraryItem],
        channels: [SubscribedChannel],
        history: [DownloadHistoryItem],
        diskUsage: Int64
    ) -> UserProfile
}
```

- 순수 계산 로직 (API 호출 없음, 즉시 반환)
- LibraryItem.tags → categoryDistribution (내림차순 정렬)
- LibraryItem.channelName → topChannels
- DownloadHistory.resolution → preferredResolution (최빈값)

### UI: ProfileView

**위치**: LibrarySidebarView 네비게이션에 "내 프로필" 항목 추가 (SF Symbol `person.text.rectangle`)
**콘텐츠**:

```
┌────────────────────────────────────────────┐
│  🎯 내 시청 성향                           │
│                                            │
│  📊 카테고리 분포                          │
│  ┌────────────────────────────────────┐   │
│  │ 기술/IT    ████████████  42%      │   │
│  │ 음악       ████████      28%      │   │
│  │ 게임       ████          15%      │   │
│  │ 교육       ███           10%      │   │
│  │ 기타       █              5%      │   │
│  └────────────────────────────────────┘   │
│                                            │
│  📺 TOP 채널                               │
│  1. 노마드코더                12개        │
│  2. 드림코딩                  8개         │
│  3. 아이유                    5개         │
│                                            │
│  ⏱ 선호 영상 길이                         │
│  10~20분 (55%)                             │
│                                            │
│  🕐 활동 시간대                            │
│  오후 9시~12시 (45%)                       │
│                                            │
│  📦 보관함                                 │
│  87개 영상 · 15개 채널 · 12.3 GB          │
└────────────────────────────────────────────┘
```

### ProfileReducer

```swift
@Reducer
struct ProfileReducer {
    @ObservableState
    struct State: Equatable {
        var profile: UserProfile?
    }
    
    enum Action: Equatable {
        case refresh
        case profileUpdated(UserProfile)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                // LibraryCacheService + ProfileService 계산
                return .run { send in
                    let items = LibraryCacheService.shared.loadItems()
                    let channels = SubscribedChannel.loadAll()
                    let profile = ProfileService.calculate(items: items, ...)
                    await send(.profileUpdated(profile))
                }
            case .profileUpdated(let p):
                state.profile = p
                return .none
            }
        }
    }
}
```

### AppReducer 변경

```swift
// State
var profile = ProfileReducer.State()

// Scope
Scope(state: \.profile, action: \.profile) { ProfileReducer() }

// Library SidebarMode 확장
enum LibrarySidebarMode: Equatable {
    case library
    case discover
    case history
    case profile   // ← 신규
}
```

---

## Step 2: 맞춤 Discover (RecommendationService)

### RecommendationService

```swift
actor RecommendationService {
    /// 사용자 tags 기반 추천 검색어 생성
    static func recommendedSearchQueries(from profile: UserProfile) -> [String]
    
    /// 특정 영상과 유사한 내 라이브러리 영상 찾기
    static func similarVideos(
        to video: LibraryItem,
        from allItems: [LibraryItem]
    ) -> [LibraryItem]
    
    /// 특정 채널과 유사한 채널 검색 (yt-dlp)
    static func similarChannels(
        to channelId: String
    ) async throws -> [String]  // channel IDs
}
```

### 로직

```
1. ProfileService.categoryDistribution 상위 3개 추출
2. 각 카테고리를 TrendingCategory에 매핑
   - "기술/IT" → .technology
   - "음악" → .music
   - "게임" → .gaming
   - etc.
3. yt-dlp ytsearch로 해당 카테고리 인기 영상 10개씩 검색
4. 이미 다운로드한 영상(videoId) 필터링
5. "🎯 당신을 위한 추천" 피드 생성
```

### DiscoverView 변경

카테고리 목록 맨 위에 `🎯 내 취향` 항목 추가:

```
📋 카테고리
🎯 내 취향        ← 신규 (상위 카테고리 자동 조합)
🔥 전체
🎵 음악
💻 기술
🎮 게임
📰 뉴스
...
```

선택 시 → `RecommendationService` 호출 → 결과 카드 그리드 표시

---

## Step 3: 의미 검색 (SearchService + SQLite FTS5)

### SearchService

```swift
actor SearchService {
    /// FTS5 검색 인덱스 재구축
    static func rebuildIndex()
    
    /// 검색 실행 (title + channelName + transcript + summary)
    static func search(query: String) -> [(item: LibraryItem, snippet: String)]
    
    /// 연관 검색어 제안 (tags/채널 기반)
    static func suggestQueries() -> [String]
}
```

### SQLite FTS5 설정

```sql
-- DatabaseManager에 추가
CREATE VIRTUAL TABLE IF NOT EXISTS video_fts USING fts5(
    video_id UNINDEXED,
    title,
    channel_name,
    transcript,
    summary,
    tokenize='porter unicode61'
);

-- 데이터 동기화 (LibraryItem 저장/수정 시)
INSERT OR REPLACE INTO video_fts(video_id, title, channel_name, transcript, summary)
VALUES (?, ?, ?, ?, ?);

-- 검색
SELECT video_id, snippet(video_fts, 2, '<b>', '</b>', '...', 32)
FROM video_fts
WHERE video_fts MATCH ?
ORDER BY rank;
```

### 검색 결과 UI

현재 LibrarySidebarView 검색 결과를 transcript snippet까지 확장:

```
┌─ "SwiftUI" 검색 ─────────────────────────────┐
│ 🔍 SwiftUI (3개)                             │
│                                               │
│ SwiftUI NavigationStack 완벽 가이드           │
│ 노마드코더 · 22분                             │
│ "...<b>SwiftUI</b>의 NavigationStack은..."    │
│ [▶ 열기] [📂 Finder]                         │
│                                               │
│ SwiftUI와 Combine 함께 사용하기               │
│ 드림코딩 · 18분                               │
│ "...<b>SwiftUI</b>에서 Combine을 활용..."     │
│                                               │
│ iOS 18 SwiftUI 신규 API 정리                  │
│ 앨런 · 25분                                   │
│ "...새로운 <b>SwiftUI</b> API..."             │
└───────────────────────────────────────────────┘
```

---

## Step 4: 다음 영상 (Up Next) — PlayerView

### PlayerReducer 변경

```swift
// State 추가
var recommendations: [LibraryItem] = []
var autoPlayCountdown: Int = 5   // 5초 카운트다운

// Action 추가
case videoDidEnd
case loadRecommendations
case recommendationsLoaded([LibraryItem])
case startAutoPlay(String)       // videoId
case cancelAutoPlay
case updateCountdown(Int)
```

### PlayerView 변경

```
┌──────────────────────────────────────┐
│           ██ 비디오 재생 ██         │
│                                      │
│                                      │
│                                      │
├──────────────────────────────────────┤
│ ⏭ 다음 영상 (5초 후 자동 재생) [취소]│
│ ┌────────┐ ┌────────┐ ┌────────┐   │
│ │ 썸네일 │ │ 썸네일 │ │ 썸네일 │   │
│ │ 제목   │ │ 제목   │ │ 제목   │   │
│ │ 채널   │ │ 채널   │ │ 채널   │   │
│ └────────┘ └────────┘ └────────┘   │
└──────────────────────────────────────┘
```

### 추천 알고리즘

```
1. 현재 영상의 tags와 일치하는 LibraryItem 필터
2. 같은 channelId 영상 우선
3. 같은 tags를 가진 영상 다음
4. 최대 3개까지 표시
5. tags 없으면 최근 다운로드 순
```

---

## Step 5: 주간 다이제스트 (DigestService)

### DigestService

```swift
actor DigestService {
    /// 주간 통계 수집
    static func collectWeeklyStats() -> DigestStats
    
    /// AI 자연어 리포트 생성 (선택)
    static func generateNarrative(stats: DigestStats) async throws -> String
}
```

### DigestStats 모델

```swift
struct DigestStats: Equatable {
    var weekStart: Date
    var weekEnd: Date
    var videosDownloaded: Int
    var totalSizeBytes: Int64
    var topChannel: String
    var topCategory: String
    var categoryDeltas: [(String, Double)]  // 전주 대비 증감률
    var missedVideos: Int                    // 구독 채널 새 영상 중 안 본 것
    var summaryCount: Int                    // 요약 실행 횟수
    var aiNarrative: String?                 // LLM 생성 문장
}
```

### AI 내러티브 생성

- 기존 `SummarizationService`의 LLM 폴백 체인 재사용
- 프롬프트: 통계 데이터를 자연어 문장으로 변환
- API 실패 시: 통계만 표시 (AI 문장 없이)

```
📊 이번 주 TubeKeep 리포트 (7/24 - 7/30)

  새로 다운로드: 12개 영상 (2.3 GB)
  가장 많이 본 채널: 노마드코더 (3개)
  인기 카테고리: 기술/IT (42% → 전주 대비 +15%)
  구독 채널 새 영상: 8개 확인 안 함

  💬 "이번 주에는 SwiftUI와 관련된 영상을
      많이 다운로드하셨네요. 특히 NavigationStack
      관련 내용이 인상적입니다."
```

### 트리거

- 앱 실행 시 마지막 다이제스트 날짜 확인
- 일주일 이상 지났으면 자동 표시
- LibrarySidebarView 하단에 "📊 이번 주 리포트" 배너
- 또는 MainView 상단 토스트

---

## 전체 일정

| Step | 작업 | 파일 수 | 의존성 |
|------|------|---------|--------|
| **1** | ProfileService + ProfileView | 4개 (신규) | 없음 |
| **2** | RecommendationService + Discover 개선 | 2개 (신규) + 2개 (수정) | Step 1 완료 필요 |
| **3** | SearchService + FTS5 | 1개 (신규) + 2개 (수정) | DatabaseManager |
| **4** | Up Next — PlayerView | 2개 (수정) | tags 데이터 |
| **5** | DigestService | 1개 (신규) + 1개 (수정) | Step 1 완료 필요 |

---

## 기술적 고려사항

### 1. SQLite FTS5

- macOS 14+ 기본 내장 (별도 라이브러리 불필요)
- `porter` tokenizer: 영어 형태소 분석 지원
- `unicode61` tokenizer: 유니코드 지원
- 한국어는 형태소 분석이 안 되지만 LIKE 검색 + substring matching 병행

### 2. LLM 활용 최소화

- Step 1 (Profile): **API 호출 없음** — 순수 계산
- Step 2 (Recommend): **API 호출 없음** — tags 매칭
- Step 3 (Search): **API 호출 없음** — SQLite FTS5
- Step 4 (Up Next): **API 호출 없음** — tags 매칭
- Step 5 (Digest): **LLM 선택 사항** — 통계만도 충분, AI 문장은 bonus

→ 5개 Step 중 LLM API가 필요한 건 Step 5의 AI 내러티브뿐.
→ API 비용 부담 거의 없음.

### 3. 성능

- ProfileService: 수천 개 item도 0.1초 내 계산 (메모리 연산)
- FTS5: 10만 row 기준 검색 < 0.01초
- Up Next: tags Set 연산으로 즉시 계산

---

---

## Step 6: 플레이어 고도화 (선행)

> v2.8.0 Step 1~5 진행 전에 플레이어 안정성부터 확보.

### 현황 (2026-07-30)

| 문제 | 원인 | 현재 대응 |
|------|------|----------|
| AV1/VP9 검은 화면 | macOS AVPlayer H/W 미지원 | ffmpeg libx264 변환 (느림) |
| MP3-in-MP4 무음 | CoreAudio `mp4a` MP3 미지원 | ffmpeg AAC 재인코딩 |
| 12K+ 해상도 무반응 | AVPlayer 렌더링 한계 초과 | ffmpeg scale=1920 다운스케일 |
| 오디오 전용 파일 스피너 | AVPlayerView가 비디오 트랙 없으면 빙글 | ffprobe 감지 → "오디오 파일" UI |
| 스트리밍 URL 레이스컨디션 | 이전 fetch 응답이 상태 덮어씀 | `cancelInFlight` 처리 완료 |
| Up Next 크래시 | `.run` 내 MainActor 작업 강제 | `MainActor.run` 래핑 완료 |
| 다운로드 코덱 비호환 | yt-dlp 포맷 정렬 미적용 | `--format-sort codec:h264` + `--audio-format aac` 적용 완료 |

### Step 6 작업 항목

| 작업 | 설명 |
|------|------|
| **6-1. 변환 엔진 개선** | ffmpeg 진행률 실시간 업데이트 버그 수정, ETA 정확도 개선, 멀티스레드 preset 적용 |
| **6-2. 오디오 전용 UI** | `hasVideo=false`일 때 앨범아트/웨이브폼/재생목록 기본 UI 제공 |
| **6-3. mpv 통합 검토** | AVKit 한계(AV1/VP9/12K/MP3) 근본 해결 위해 libmpv 백엔드 조사 ([PLAN_v2.8.0_mpv.md](PLAN_v2.8.0_mpv.md)) |
| **6-4. 에러 상태 UI** | AVPlayerItem.failed, streamFetchFailed, transcodeFailed 각각 사용자 메시지 표시 |
| **6-5. PlayerReducer 단위 테스트** | loadVideo / streamURLFetched / upNext / cancel 시나리오 자동 검증 |

### 완료
- [x] AV1/VP9 → ffmpeg libx264 변환
- [x] 해상도 > 2160p → 1080p 다운스케일
- [x] MP3 오디오 → AAC 재인코딩
- [x] 오디오 전용 파일 `hasVideo` 감지 + fallback UI
- [x] 스트리밍 fetch `cancelInFlight` 레이스컨디션 수정
- [x] Up Next `MainActor.run` 크래시 수정
- [x] 다운로드 `--format-sort codec:h264` + `--audio-format aac` 적용

---

## 보류/제외

| 기능 | 사유 |
|------|------|
| 협업 필터링 (다른 사용자 데이터) | 싱글 유저 앱이라 불필요 |
| 실시간 스트리밍 추천 | yt-dlp 검색 제약으로 무의미 |
| 시청 시간 기반 추천 | AVPlayer 시청 시간 추적 미구현 (향후 고려) |
| 감정/분위기 기반 추천 | transcript 감정 분석은 LLM 비용 대비 효용 낮음 |
