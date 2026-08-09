# PLAN v3.7 — 채널 인사이트 (macOS)

> 플랫폼: macOS (TubeKeep 네이티브) · 작성일: 2026-08-08
> 이전 버전: v3.6 유휴 자동화 반복·팝업 안정화

## 1. 개요

유휴 자동화로 쌓인 자막·요약·태그·조회수 데이터를 채널 단위로 집계해 **채널 인사이트**를 제공한다.
채널 선택 시 기존 `ChannelHeaderView` 하단에 카드+카테고리 분포+AI 주제 요약을 표시.

## 2. 결정 사항

1. **표시 위치**: 채널 상세 상단 인세트 (`ChannelHeaderView` 바로 아래, grid/list 공통)
2. **생성 방식**: 통계(태그·길이·조회수)는 코드 계산, "채널 주제" 요약만 기존 OpenRouter 무료 체인(A.X→Gemini 폴백) 사용
3. **AI 요약 최소 기준**: 보관함 영상 **10개 이상**일 때만 생성 (text pool 부족 시 안내 문구)
4. **AI 비용 최적화**: 1회 생성 → UserDefaults 캐시(channelId→요약, TTL 30일) + "다시 생성" 버튼으로 갱신, 캐시 히트 시 AI 호출 생략
5. **프롬프트**: tags 카운트 + 최근/인기 영상 title + 요약(suffix 1500자×최대 5개) 조합 — transcript 전체 사용 금지(토큰 절약)
6. 통계는 항상 표시 (AI 호출과 무관)

## 3. 아키텍처

### 3.1 모델 (`Sources/TubeKeep/Models/ChannelInsights.swift`)
```
struct ChannelInsightStats {
    var videoCount: Int
    var tagCounts: [String: Int]          // 카테고리 → 개수
    var averageDuration: Int              // 초
    var totalMinutes: Int
    var topCategories: [(String, Int)]    // 상위 3~5
    var topViewedVideo: (title: String, viewCount: Int)?
}
```

### 3.2 서비스 (`Sources/TubeKeep/Services/ChannelInsightService.swift`)
```
final class ChannelInsightService {
  static func compute(channelId: String, items: [LibraryItem]) -> ChannelInsightStats
  func summarize(channelId: String, items: [LibraryItem]) async -> String?  // 체인+캐시
}
```
- compute: 채널 영상 필터 → tagCounts/duration 평균/조회수(ChannelDownloadCache.cachedVideos) 집계
- summarize: `needsSummary(items.count) -> Bool (>=10)`, UserDefaults 캐시 확인, `AIFallbackSummary` 방식 재사용(OpenRouter→AX4→Gemini), 실패 시 nil(통계만 표시)

### 3.3 유저 Defaults 캐시
키 `channelInsightSummary:<channelId>` → `{ summary, generatedAt }` (TTL 30일)

### 3.4 UI (`Sources/TubeKeep/Features/Library/ChannelInsightCardView.swift`)
- 카드 4종: 보관함 개수 / 평균 길이 / 대표 카테고리(상위 3) / 최고 조회 영상
- 카테고리 분포 막대(HStack + GeometryReader 비율)
- AI 요약 문단(로딩/캐시 히트 상태/실패), "다시 생성" 버튼

### 3.5 통합
- `ChannelHeaderView` body 하단에 `ChannelInsightCardView` 배치 (같은 `items` 파라미터 공유)

## 4. 구현 단계 (T#)

| T# | 작업 | 상태 |
|----|------|------|
| T-370 | PLAN_v3.7 + TODO 등록 | done |
| T-371 | ChannelInsights 모델 + compute 통계 서비스 | pending |
| T-372 | summarize 체인 + UserDefaults 캐시(30일)+최소 10개 가드 | pending |
| T-373 | ChannelInsightCardView UI (카드+막대+요약 문단) | pending |
| T-374 | ChannelHeaderView 하단 통합 | pending |
| T-375 | 빌드 debug macos + 채널 선택 검증 + doc/session | pending |

## 5. 테스트 계획
- TC-1: 채널 선택 시 인세트 표시 (영상 0~9개 → 통계만, AI 문단에 "10개 필요" 안내)
- TC-2: 10+ 채널 → AI 요약 생성 → 재선택 시 캐시 히트(재생성 없음), "다시 생성"으로 갱신
- TC-3: 카테고리 분포 막대가 tags와 일치 / 평균 길이 정확
- TC-4: 최고 조회 영상이 ChannelVideoItem.viewCount 기반 표시
- TC-5: API 키 없으면 통계만 표시, 크러쉬 없음

## 6. 롤백
- `ChannelHeaderView`에서 인세트 뷰 제거 + 신규 3파일 삭제로 즉시 복구 (SwiftData/DB 마이그레이션 없음)
- UserDefaults 캐시 키는 기존 데이터 영향 없음

## 7. 에러코드
- 신규 없음 (통계는 로컬, AI 실패는 조용히 통계만 표시)