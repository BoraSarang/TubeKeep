# PLAN v3.12 — Hallmark 스킬 도입 + 랜딩 페이지 리디자인 + 디자인 원칙 반영 (macOS)

## 개요
v3.11(릴리즈) 완료 후 사용자가 요청한 **Hallmark**(Anti-AI-slop 디자인 스킬, nutlope/hallmark)를 opencode 전용 skills 디렉토리에 설치하고, TubeKeep 랜딩 페이지(`docs/index.html`)를 신규 레드 브랜드 아이콘과 매칭되도록 리디자인한다. 아울러 SwiftUI 네이티브 앱에 적용 가능한 anti-slop 원칙만을 설계 문서(DESIGN_SYSTEM.md)에 반영한다.

**원칙**: 앱 Swift 코드는 수정하지 않음(문서 + 웹 랜딩만), 한국어 문서 우선, 1커밋 1관심사.

## 결정 사항
- Hallmark 설치 위치: `~/.config/opencode/skills/hallmark/` (opencode 전용 글로벌 스킬)
- 랜딩 히어로: **레드 브랜드 전면 교체** (기존 그라데이션/중앙정렬 대신 비대칭 비정렬 + 단일 앵커)
- 커밋: 3개 분리 (설치+문서 / 랜딩 개편 / DESIGN_SYSTEM)
- 설치 방식: `npx skills add`(Claude 경로) 대신 GitHub 저장소 tarball을 직접 내려받아 opencode 전용 경로에 구성

## 아키텍처

### 1. Hallmark 스킬 설치 (글로벌, opencode 전용)
- **경로**: `~/.config/opencode/skills/hallmark/`
  - `SKILL.md` (67KB, frontmatter name=hallmark / description 검증 완료 → opencode 규격 충족)
  - `references/` (106개 파일: themes/genres/macrostructures/components/verbs/anti-patterns 등 카탈로그)
  - `site/css/tokens.css` (SKILL.md가 참조하는 테마 토큰 소스)
  - `site/examples/cobalt-01/`, `site/_tests/01~08/` (SKILL.md·references·docs/recipes.md가 참조하는 예시 자산)
  - `docs/recipes.md`, `docs/study-examples.md` (인간 독자용 worked briefs)
- **경로 정규화**: 원본 저장소 기준 상대경로(`../../site/...`)를 설치 구조(스킬 폴더를 루트로)에 맞게 재계산 → 참조 무결성 283/283 확인 ✅
- opencode 로드는 재시작 시 `<available_skills>`에 `hallmark` 노출 예정

### 2. 랜딩 페이지 리디자인 (docs/index.html + style.css)
- **대상**: `docs/index.html` (108줄) + `docs/style.css` (182줄), vanilla HTML+CSS, GitHub Pages 호환 유지
- **현재 anti-pattern (Hallmark 슬롭 지적)**: 중앙정렬 히어로 + 3색 그라데이션 텍스트 + 이모지 타일 카드 6장 + 단일 시스템 폰트
- **개편 방향** (새 레드 아이콘 매칭):
  - 히어로: 비대칭 좌/우 이중 앵커, 단일 레드 앵커, `hero-title` 그라데이션 제거
  - 폰트 페어링: 디스플레이(한글 대체 포함) + 바디 2계통
  - 기능 카드: 이모지 타일 → 서수/마이크로타이포그래피 강조로 대체
  - 반응형: 320/375/414/768px 검증 (Hallmark 게이트), `overflow-x: clip`, 이모지·중앙정렬 회피
  - 콘텐츠/스크린샷 경로(`screenshots/app/*.png`) 불변
- **검증 방법**: 로컬 HTTP 서버(`python3 -m http.server`) + chrome-devtools 미리보기(히어로/기능/반응형)

### 3. DESIGN_SYSTEM.md Anti-Slop 지침 섹션 추가
- SwiftUI에 수용 가능한 원칙만 문서화 (코드 수정 없음):
  - 단일 앵커 색 + 그라데이션 과용 금지
  - 타이포 페어링(디스플레이/바디 2+1) + `@AppColors`/`@AppFont` 토큰과 연계
  - 대칭/중앙정렬 회피 원칙
  - 8-state 상호작용, 이모지 대신 SF Symbol 가이드

## 구현 단계 (T-번호)
| ID | 작업 | 상세 |
|----|------|------|
| T-1120 | **PLAN_v3.12 + TODO 등록** | docs/plans/PLAN_v3.12_landing-macos.md |
| T-1121 | **Hallmark 스킬 설치** | ~/.config/opencode/skills/hallmark/ (SKILL.md+references+site+docs, 경로 정규화) |
| T-1122 | **랜딩 audit → redesign** | docs/index.html + style.css 레드 브랜드 전면 개편 |
| T-1123 | **랜딩 미리보기 검증** | 로컬 HTTP + chrome-devtools, 반응형 4폭 검증 |
| T-1124 | **DESIGN_SYSTEM.md Anti-Slop 섹션** | SwiftUI 수용 가능 원칙 문서화 |
| T-1125 | **문서 마감 + 커밋 3분리** | CHANGELOG/TODO/세션 로그 + 설치문서 커밋·랜딩 커밋·DESIGN_SYSTEM 커밋 |

## 테스트 계획
- 랜딩: chrome-devtools 미리보기 + 320/375/414/768px 반응형 확인 (앱 빌드 불필요 — Swift 코드 무변경)
- 스킬: opencode 재시작 후 `<available_skills>`에 hallmark 노출 확인 (다음 세션)

## 롤백 계획
- 랜딩: `git revert` 랜딩 커밋 → 기존 index.html/style.css 복원
- 스킬: `rm -rf ~/.config/opencode/skills/hallmark` (로컬 전용, repo 영향 없음)
- DESIGN_SYSTEM: `git revert` 해당 섹션 커밋

## 성능 예산
- 랜딩 LCP 유지(파일 수·이미지 경로 불변), 스크립트 추가 없음
- 스킬 설치 크기 1.2MB(글로벌) — opencode 로드 성능 영향 없음(지연 로드)

## 에러코드
- 추가 없음 (documentation-only, 사용자 노출 메시지 없음)