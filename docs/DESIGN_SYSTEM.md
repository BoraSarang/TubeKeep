# DESIGN_SYSTEM.md — 디자인 시스템 (macOS)

> TubeKeep macOS 앱의 UI 일관성을 위한 디자인 시스템 정의서.
> 목표: **중복 UI 제거 + 한 곳에서 수정 + 내가 보기 좋은 기본값 통일**.
> 문서 우선 원칙(T-1080~T-1083)에 따라 계획 → 코드 → 문서 순서로 작성.

**버전**: v1.0 (2026-08-06) · **플랫폼**: macOS

---

## 1. 개요

기존 코드는 공통 컴포넌트 없이 3~5중 중복이 존재했다.
(예: 정렬 바 2곳, 선택 바 3곳, 배지 캡슐, EmptyState 4곳, 검색 필드 3곳)

디자인 시스템은 이 중복을 L1~L4 4계층으로 정리해 제거한다.
**색은 시스템 블루(accentColor)를 유지**하고, 작업 단계에서 `.blue/.orange/.green` 등
시스템 색을 직접 쓰지 않고 반드시 `AppColors` 토큰을 경유한다.

## 2. 4계층 구조

```
L1 DesignTokens        DesignTokens.swift   색(AppColors)/폰트(AppFont)/간격(AppMetrics)
L2 프리미티브          Components/          AppSearchField, StatusBadge, EmptyStateView,
                                            AppPrimaryButton, ErrorBanner, SectionHeader
L3 복합 컴포넌트        Components/          LibrarySortBar, SelectionBar
L4 패턴(화면 적용)     Features/*           화면에서 L2·L3 조합 + 문서 갱신
```

- **색/폰트/간격은 L1 토큰으로만 참조** (화면에 직접 하드코딩 금지)
- 프리미티브는 독립적으로 동작하는 단일 UI 요소
- 복합 컴포넌트는 프리미티브 + L1 토큰 조합 (예: 정렬 바, 선택 바)
- ButtonStyle을 채택하지 않아 기존 버튼 스타일과 충돌 없음

## 3. 토큰 (L1)

### 3.1 색상 `AppColors`

| 토큰 | 값 | 용도 |
|------|-----|------|
| `accent` | `Color.accentColor` | 포인트 색 (시스템 블루 유지) |
| `success` | `.green` | 성공/완료 |
| `warning` | `.orange` | 경고/진행 |
| `danger` | `.red` | 오류/삭제 |
| `info` | `.blue` | 정보 |
| `badgeSubtitle` | `.blue` | 자막 존재 배지 |
| `badgeChapters` | `.orange` | 챕터 배지 |
| `badgeSummary` | `.green` | 요약 배지 |
| `badgePodcast` | `.purple` | 팟캐스트 배지 |
| `badgeResume` | `accent` | 이어보기 배지 |
| `progressActive` | `.blue.opacity(0.08)` | 다운로드 진행 중 배경 |
| `progressCompleted` | `.green.opacity(0.06)` | 완료 배경 |
| `progressTrack` | `.black.opacity(0.4)` | 재생 진행 트랙 |
| `selectionRow` | `accent.opacity(0.1)` | 선택된 행 배경 |
| `waveBaseGradient` | 블루 계열 3색 | WaveProgress 배경 |
| `waveShimmer` | `.white.opacity(0.2)` | WaveProgress 쉬머 |
| `waveAccentLine` | 블루 라인 | WaveProgress 라인 |
| `overlayBadge` | `.black.opacity(0.75)` | 썸네일 오버레이 배지 배경 |
| `cardShadow` | `.black.opacity(0.2)` | 카드 그림자 |

### 3.2 폰트 `AppFont`

| 토큰 | 값 | 용도 |
|------|-----|------|
| `cellTitle` | 12pt medium | 목록/그리드 셀 제목 |
| `cellSubtitle` | 11pt | 셀 부제(채널명 등) |
| `meta` | 10pt | 메타 정보 (업로드일, 이어보기 등) |
| `count` | 11pt | 개수/선택 바 텍스트 |
| `badge` | 10pt semibold | 캡슐 배지 텍스트 |
| `badgeIcon` | 10pt bold | 배지 아이콘 |
| `sidebarRow` | 12pt | 사이드바 행 |
| `sectionHeader` | 11pt semibold | 섹션 헤더 |
| `statusBarText` | 10pt monospaced | 상태바 텍스트 |

### 3.3 메트릭 `AppMetrics`

| 토큰 | 값 | 용도 |
|------|-----|------|
| `paddingSmall` | 8 | 작은 패딩 |
| `paddingStandard` | 12 | 기본 패딩 |
| `paddingLarge` | 16 | 큰 패딩 |
| `cornerSmall` | 4 | 작은 라운드 |
| `cornerStandard` | 6 | 기본 라운드 |
| `cornerLarge` | 10 | 큰 라운드 |
| `badgeStackOffset` | 28 | 배지 스택 오프셋 |
| `capsuleHPadding/VPadding` | 8/5 | 캡슐 배지 패딩 |
| `capsuleHPaddingSmall/VPaddingSmall` | 6/4 | 작은 캡슐 패딩 |
| `rowIconSize` | 18 | 행 아이콘 크기 |

## 4. 컴포넌트 카탈로그 (L2·L3)

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `AppSearchField` | AppSearchField.swift | 돋보기 + 클리어 버튼 검색 필드 (`isSearching`/`onSubmit` 지원) |
| `StatusBadge` | StatusBadge.swift | `.capsule`(아이콘+텍스트) / `.inline`(아이콘, 텍스트 선택) 배지 |
| `EmptyStateView` | EmptyStateView.swift | 아이콘+제목+제네릭 액션 빈 상태 |
| `AppPrimaryButton` | AppPrimaryButton.swift | 프라이머리 버튼 (`size: .small/.regular`, 시스템 이미지) |
| `ErrorBanner` | ErrorBanner.swift | 경고 배너 (`onDismiss` 선택) |
| `SectionHeader` | SectionHeader.swift | 사이드바/목록 섹션 헤더 |
| `LibrarySortBar` | LibrarySortBar.swift | 항목 수 + 썸네일 토글 + 정렬 Picker + 보기 모드 전환 |
| `SelectionBar` | SelectionBar.swift | 전체 선택/Finder/열기/선택 해제/삭제 (`onOpen`, `showsDeselect` 옵션) |

## 5. 적용 화면 현황

| 화면 | 적용 항목 | 상태 |
|------|-----------|------|
| DownloadQueueView | WaveProgress RGB, 상태 색, 진행 배경, 오버레이 배지, `.monospacedDigit()` | ✅ 완료 |
| LibraryGridView | LibrarySortBar, SelectionBar, EmptyStateView(+AppPrimaryButton), StatusBadge 5종, AppFont | ✅ 완료 |
| LibraryListView | LibrarySortBar, SelectionBar, EmptyStateView, StatusBadge 3종, AppFont | ✅ 완료 |
| ChannelHeaderView | AppPrimaryButton 3개 (borderedProminent 교체) | ✅ 완료 |
| LibrarySidebarView | AppSearchField 3종, SectionHeader 4곳 | ✅ 완료 |
| DiskCleanupView | SelectionBar(showsDeselect:false), EmptyStateView | ✅ 완료 |
| QAView | ErrorBanner | ✅ 완료 |
| AIWindowView | ErrorBanner (mindmap, qna) | ✅ 완료 |

## 6. 규칙

1. **색 규칙**: 작업 단계에서 `.blue/.orange/.green/.red` 직접 사용 금지 → `AppColors` 경유.
   시스템 UI 전용(인라인 아이콘 등)으로 불가피한 경우도 토큰 정의 후 사용.
2. **폰트 규칙**: 셀/배지/헤더는 `AppFont` 경유. 상태바 등 특수 폰트는 토큰화.
3. **중복 규칙**: 정렬 바, 선택 바, 빈 상태, 배지, 검색 필드는 기존 화면에서 컴포넌트로 교체.
4. **새 화면**: 신규 화면은 L2/L3 컴포넌트 + L1 토큰만 사용.
5. **ButtonStyle 미채택**: `AppPrimaryButton` 등은 ButtonStyle을 채택하지 않아
   `buttonStyle(.borderedProminent)` 등 기존 지정과 충돌 없음.
6. **시스템 블루 유지**: 포인트 색은 `Color.accentColor` 고정, 임의 RGB 도입 금지
   (WaveProgress 등 그래디언트는 예외 — 시각적 특수성이 필요하므로 토큰으로 캡슐화).

## 7. 테스트 규칙

- 디자인 시스템 변경 후: `swift build -c debug` → `swift test`(76개) → `./scripts/test-core.sh`(23 PASS)
- UI 회귀는 Grid/List/다운로드 큐/사이드바 수동 확인
- grep으로 잔여 하드코딩 확인: `rg '\.blue\b|\.orange\b|\.green\b|\.red\b' Features/`

---

## 8. Anti-Slop 지침 (v3.12, Hallmark 원칙 적용)

> 출처: turnkey 디자인 스킬 **Hallmark** (nutlope/hallmark, 2026·MIT).
> 아래는 macOS **SwiftUI 네이티브**에 수용 가능한 원칙만 추려 문서화한 것이다.
> 웹 카탈로그(그리드·테마·매크로구조)는 적용 대상이 아니며, 랜딩 페이지(`docs/`)에는 그대로 적용한다.

### 8.1 단일 앵커 색 + 그라데이션 과용 금지

- 포인트 색은 **하나**만 둔다: 시스템 블루(`Color.accentColor`) 유지.
- 같은 화면에서 앵커 외 2색 이상의 채도 높은 색을 뿌리지 않는다. 배지 4종
  (`badgeSubtitle/badgeChapters/badgeSummary/badgePodcast`)은 **용도별 상태 색**이므로 예외 —
  단 UI 포인트로 쓰지 말고 상태 표지로만 사용.
- 그라데이션(Gradient)은 `waveBaseGradient`처럼 **한 화면 한 곳**에만 허용.
  텍스트·버튼·히어로에 다중 그라데이션 텍스트 금지. (v3.11 랜딩의 3색 히어로 그라데이션 →
  v3.12에서 단일 레드 앵커로 교체한 사례 참고)

### 8.2 타이포 페어링 (2+1)

- 화면에는 **디스플레이(제목/강조) 1 + 바디 1(+ 모노스페이스 1)** 계통만 사용.
- `AppFont` 토큰은 바디 계통이며, 화면 제목·수치는 `fontDesign(.rounded)` 등으로
  "강조" 계통을 구분할 수 있다. 단 앱 전역에 표시 전용 폰트를 여럿 도입하지 않는다.
- 헤딩 이탤릭 금지: 굵기·색·밑줄로 강조한다.

### 8.3 대칭/중앙 정렬 회피

- 카드 그리드·배너는 단순 중앙 정렬 반복을 피하고, 좌 얼라인 + 의도적 비대칭
  (구간별 다른 패딩)을 사용한다.
- 기능 설명 등 정보성 콘텐츠는 중앙보다 좌측 정렬이 눈에 편하다.

### 8.4 상호작용 8-state

- 새 인터랙티브 컴포넌트는 **default · hover · focus-visible · active · disabled · loading · error · success**
  8개 상태를 모두 신경 쓴다.
- 목록/그리드 셀 hover·선택·진행·오류는 `LibraryGridView`·`DownloadQueueView`의
  기존 상태 피드백을 기준으로 한다.

### 8.5 진실한 복사 (honest copy)

- 지표(Metric)는 실제 측정값만 표기하고, 허구 수치(예: "10× faster", "50,000+ teams")를 넣지 않는다.
- '인증', '추천 수' 등 검증되지 않은 주장을 UI에 표기하지 않는다.

### 8.6 이모지 금지, SF Symbol 사용

- UI 텍스트에서 이모지를 장식으로 쓰지 않는다. 아이콘은 반드시 SF Symbol
  (`Label`·`Image(systemName:)`)을 사용한다.
- 랜딩 페이지도 유튜브 스타일 개편에서 이모지 타일을 SVG 아이콘으로 대체함(참고).

### 8.7 반응형/다크-라이트

- 랜딩은 320/375/414/768px 오버플로 없는 것을 기본 게이트로 삼는다
  (딥다크 `#0f0f0f` + 유튜브 레드 `#ff0000` 팔레트, `prefers-color-scheme: light` 분기).
- macOS 앱은 시스템 색(NSColor/SwiftUI) 경유 — 다크/라이트 자동 대응 유지.
