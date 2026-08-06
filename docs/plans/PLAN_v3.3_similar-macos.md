# PLAN v3.3 — 비슷한 영상 검색 (Similar Videos) — macOS

> 작성일: 2026-08-06 · 플랫폼: macOS · 상태: 구현 전
> 관련: bd 없음 (신규 기능) · TODO: T-1084~T-1087

## 1. 개요

재생 중인 영상의 제목·채널·AI 카테고리 태그를 기존 AI 체인으로 분석해 **한글 검색어 3~4개**를 생성하고,
기존 `TrendingService.search`(yt-dlp `ytsearch`)로 **실제 유튜브에서 관련성이 높은 영상**을 검색해
플레이어 툴바 버튼 → 오른쪽 사이드 패널에 표시하는 기능.

- **목표**: "이 영상이랑 비슷한 유튜브 영상 찾기" — 트렌드/주제 반영 검색.
- **수단**: AI 검색어 생성(OpenRouter → Gemini → 규칙 폴백) + `yt-dlp ytsearch` (기존 인프라 재사용).
- **참고**: YouTube 공식 API `relatedToVideoId`는 2023-08-07 지원 종료로 사용 불가 → 검색어 기반 접근 채택.

## 2. 결정 사항

| 결정 | 내용 |
|------|------|
| 검색어 생성 | AI 사용 (OpenRouter → Gemini → 규칙 폴백). AI 실패/키 없어도 제목 기반 폴백으로 항상 동작 |
| 검색어 언어 | 한글 키워드 (앱 UI/태깅과 일관) |
| 검색 실행 | 기존 `TrendingService.search(query:maxResults:)` — yt-dlp `ytsearchN:` 병렬 호출 후 병합 |
| 결과 행동 | 목록 클릭 → 해당 영상으로 **즉시 재생 전환** (`openPlayerWindow` + `PlayerItem` 생성) |
| 캐시 | 검색어는 UserDefaults에 videoId별 저장 (7일 TTL) — DB 스키마 변경 없음 |
| API 키 | 신규 키 불필요 — 기존 `openRouterAPIKey` / `geminiAPIKey` 재사용 (`Settings.loadAPIKeys()`) |

## 3. 아키텍처

```
PlayerView(툴바 버튼 ⭐)
   │ store.send(.loadSimilarVideos)
   ▼
PlayerReducer.loadSimilarVideos
   │ playerItem.videoId/title + LibraryCacheService.findItem(channelName) + tags + DB 요약
   ▼
SimilarVideoService.generateQueries(videoId:title:channel:tags:summary)
   │ 1) UserDefaults 캐시 hit → 반환
   │ 2) OpenRouter.chatCompletion(한글 검색어 3~4개 JSON)
   │ 3) GeminiService.query 폴백
   │ 4) 규칙 폴백 (제목/채널/태그 → 검색어)
   ▼ (검색어 3개)
TrendingService.search ×3 (async let 병렬)
   │ 병합 · 중복 제거 · 현재 영상 제외 · 정렬
   ▼
similarVideosLoaded([TrendingVideo]) → PlayerView SimilarVideosPanel
```

### 신규/변경 파일

| 파일 | 변경 |
|------|------|
| `Services/SimilarVideoService.swift` | **신규** — 검색어 생성(AI 체인 + 규칙 폴백) + UserDefaults 캐시 + 검색 병합 |
| `Features/Player/PlayerReducer.swift` | State `similarVideos/isLoadingSimilar/similarError/showSimilarVideos`, Action 4종 추가 |
| `Features/Player/PlayerView.swift` | 툴바 버튼 + `similarVideosPanel`(사이드 패널, showSubtitlePanel/showQueue와 상호 배타) |
| `Models/TrendingVideo.swift` | 재사용 (변경 없음) |
| `docs/AI_MODELS.json` | `models.similar` 추가 (prompt_version, chain, cache) |

## 4. 구현 단계 (T-번호)

- **T-1084** — `SimilarVideoService` 신규: `generateQueries`(AI 체인 + 규칙 폴백 + UserDefaults 캐시) + `searchSimilar`(병렬 검색·병합)
- **T-1085** — `PlayerReducer` 확장: State `similarVideos/isLoadingSimilar/similarError/showSimilarVideos`, Action `loadSimilarVideos/similarVideosLoaded/similarVideosFailed/toggleSimilarVideos/clearSimilarVideos`
- **T-1086** — `PlayerView` UI: 툴바 "비슷한 영상" 버튼 + `SimilarVideosPanel`(로딩/오류·재시도/빈 상태, 클릭→재생 전환, 컨텍스트 메뉴 다운로드/유튜브 열기)
- **T-1087** — 검증: `make build` + `swift test`(76개) + 실제 재생 영상으로 검색어 생성→검색→목록→재생 전환 수동 확인

## 5. 테스트 계획

- TC-SIM-001: 검색어 생성 — AI 키 있는 경우(OpenRouter) 한글 검색어 3~4개 반환
- TC-SIM-002: 폴백 — 키 없는 경우에도 제목/태그 기반 검색어 반환 (기능 동작 보장)
- TC-SIM-003: 검색 — `TrendingService.search`로 실제 유튜브 결과 반환, 현재 영상 제외
- TC-SIM-004: UI — 툴바 버튼 토글 → 패널 표시/숨김, 로딩, 오류 재시도, 클릭 시 재생 전환
- TC-SIM-005: 캐시 — 같은 영상 재요청 시 AI 재호출 없이 UserDefaults 캐시 반환

## 6. 롤백 계획

- `git revert` 대상 커밋 (T-1084~1087 커밋) — 신규 파일 1개 + 기존 2개 수정이므로 리버트 시 안전
- UserDefaults 캐시 키 `similarQueriesCache` 삭제 시 재생성
- 플레이어 패널은 기존 패널(자막/큐)과 상호 배타 분기라 기존 동작 영향 없음

## 7. 성능 예산

- 검색어 생성: AI 응답 대기 ≤ 60초 (기존 GeminiService.timeout)
- 검색 3쿼리 병렬: 각 ≤ 30초 (ProcessRunner 기본), 총 ≤ 35초 예상
- 캐시 히트 시: 네트워크/LLM 호출 0회 → 즉시 표시
- 패널 320pt (기존 panelWidth) — 창 크기 windowWidth 계산에 반영

## 8. 에러코드 목록

- 별도 신규 에러코드 없음 — 실패 시 `similarError`에 localizedDescription 표시
- yt-dlp 미설치/실패는 기존 `YTDLPError` 흐름 그대로 (ErrorMessageMapper)

## 9. 문서 업데이트

- docs/TODO.md (T-1084~1087)
- docs/DESIGN.md (2.9 PlayerReducer 확장 + 신규 서비스 + 파일 구조)
- docs/AI_MODELS.json (models.similar)
- docs/CHANGELOG.md (개발 중 섹션)
