# PLAN v4.6 — macOS 네이티브 디자인 리빌딩 2차 (플레이어 + AI + 다운로더)

> 작성: 2026-08-20 · 플랫폼: macOS · 버전: v4.6
> 사용자 결정: ① 플레이어에 AI 패널 추가 + 기존 AI 창 유지 ② 다운로더 3종 포함(순서대로) ③ AI 창은 보관함 전용 ④ 플레이어 컨트롤바 자동 숨김 ⑤ 창 크기 자유 재량

---

## 1. 개요

v4.5의 디자인 리빌딩(설정/사이드바)에 이어, AI 기능 창·영상 플레이어·다운로더 3종을 macos-app-design 스킬 기준으로 네이티브하게 다듬는다. 목표는 "첫눈에 맥 앱", 맥 사용자에게 이질감 없는 UX/UI.

### 진단 (macos-app-design 기준)
- **공통 문제**: 모든 창 툴바에 `xmark.circle`(닫기) 버튼 — traffic lights와 중복. 커스텀 `AppColors` 사용, 폰트 8~11px(맥 표준 13px보다 작음), 4pt 그리드 미준수
- **플레이어**: 창 리사이즈 시 비디오 비율 무시 스트레치, 컨트롤바 상시 표시(몰입감 저하), 패널 배경 `windowBackgroundColor` 하드코딩
- **AI 창**: 560×560에 요약/챕터/마인드맵/Q&A 4분할이 조밀하게 압축
- **다운로더 3종**: 창 크기/밀도/폰트 모두 표준 이탈

---

## 2. 결정 사항

| 항목 | 결정 |
|------|------|
| AI+플레이어 통합 | 플레이어 우측 패널에 **AI 패널 5번째 토글** 추가, AppReducer store 주입, AIWindowView 4섹션을 공용 컴포넌트로 추출해 공유 |
| AI 창 | 보관함 전용 유지, 4섹션 컴포넌트 재사용, 툴바 정리 |
| 플레이어 컨트롤바 | 마우스 움직임 감지 → 2.5초 후 자동 숨김, 움직이면 복귀 (IINA/QuickTime 관례) |
| 비디오 비율 | 창 크기와 무관하게 16:9 유지 + 레터박스 |
| 툴바 | 모든 창 `xmark.circle`(닫기) 제거 → traffic lights에 위임, pin은 유지 |
| 색상 | `AppColors` 커스텀 → 시스템 semantic(`Color(.controlBackgroundColor)` 등) + material(Liquid Glass 분기) |
| 폰트 | 8~11px → macOS 표준 11~13px |
| 채널 다운로더 사이드바 | 180 → 200px (사용자 선호) |

---

## 3. 아키텍처

### 3.1 플레이어 (Step 1, T-1201)
```
PlayerView
  ├─ store: PlayerReducer (+ AppReducer 주입 신설)
  ├─ videoArea (16:9 레터박스 + 컨트롤바 오토하이드)
  └─ rightPanel
       ├─ queuePanel / subtitlePanel / similarVideosPanel (기존)
       └─ aiPanel (신규) ← AISectionViews 공용 컴포넌트
PlayerReducer
  ├─ State.showAIPanel: Bool
  └─ Action.toggleAIPanel (기존 패널과 상호 배타)
```

### 3.2 AI 창 (Step 2, T-1202)
```
AIWindowView (보관함 전용)
  └─ AISectionViews (신규 공용 컴포넌트)
       ├─ AISummarySection / AIChapterSection / AIMindmapSection / AIQnASection
       └─ AI 패널과 AI 창이 동일 컴포넌트 사용
```

---

## 4. 구현 단계 (T-번호)

### Step 1 — 플레이어 (T-1201)
- PlayerReducer: `showAIPanel` + `toggleAIPanel` (상호 배타: 나머지 패널 off)
- AppDelegate.openPlayerWindow: `PlayerView`에 `store`(AppReducer) 주입
- PlayerView: rightPanel에 aiPanel 추가, 툴바에 AI 토글(sparkles), `xmark.circle` 제거
- 컨트롤바 오토하이드: `.onContinuousHover` + 타이머 2.5s
- 비디오 비율: videoArea를 16:9 고정 + 검정 레터박스
- 패널 배경 → `.regularMaterial` (macOS 26 분기)

### Step 2 — AI 창 (T-1202)
- AIWindowView의 4섹션을 `AISectionViews.swift`(Features/AI/)로 추출
- AIWindowView가 재사용, 플레이어 aiPanel도 동일 컴포넌트 사용
- 툴바 `xmark.circle` 제거, 폰트/색상 표준화, 창 크기 정돈

### Step 3 — 다운로더 3종 (T-1203)
- 영상 다운로더: 툴바 닫기 제거 + 폰트/색상 표준화 + HomeView/DownloadQueueView 간격 정돈
- 일괄 다운로더: 창 확대(640×560) + 헤더/GroupBox 정돈 + 폰트/색상 표준화 + 툴바 닫기 제거
- 채널 다운로더: 사이드바 200px + 툴바 닫기 제거 + 하단 상태바 시스템 컬러

### Step 4 — 문서·검증 (T-1204)
- 빌드 + a11y 덤프(각 창 툴바/패널/폰트) + 스크린샷 + CHANGELOG v4.6

---

## 5. 테스트 계획
- TC-1201: 플레이어 AI 패널 토글 → 재생 영상 요약/챕터/마인드맵/Q&A 표시, 다른 패널과 상호 배타
- TC-1202: 컨트롤바 마우스 안 움직이면 2.5초 후 숨김, 움직이면 복귀
- TC-1203: 창 리사이즈 시 비디오 16:9 유지(레터박스)
- TC-1204: 다운로더 3종 툴바에 닫기 없음, 폰트/색상 표준 확인
- 검증 수단: a11y 덤프 + 스크린샷(/tmp) + 사용자 확인

## 6. 롤백 계획
- git revert (이번 버전 커밋 단위)
- 기존 창 상태 복원은 자동 (설정 미변경)
- UserDefaults/키체인 변경 없음

## 7. 에러코드/권한
- 신규 에러코드 없음 (UI 변경만)
- 권한 변경 없음