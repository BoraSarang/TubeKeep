# TubeKeep 문서 가이드

이 폴더는 TubeKeep 프로젝트의 문서를 체계적으로 관리하기 위한 것입니다.

---

## 문서 분류

### 핵심 문서 (반드시 유지보수)

| 파일 | 목적 | 설명 |
|------|------|------|
| [AGENTS.md](AGENTS.md) | AI 에이전트 가이드 | 작업 규칙, 파일 관리 규칙, 버전 진행 규칙 |
| [PRD.md](PRD.md) | 제품 요구사항 정의 | 사용자 스토리, 기능 명세, 제약 조건 |
| [DESIGN.md](DESIGN.md) | 기술 설계 문서 | 아키텍처, 데이터 흐름, 컴포넌트 설계 |
| [PLAN.md](PLAN.md) | 구현 일정/계획 | 완료된 작업, 진행 중 작업, 향후 계획 |
| [TODO.md](TODO.md) | 작업 추적 목록 | 세부 할 일 목록 (상태 관리) |

### 참조 문서

| 파일 | 목적 | 설명 |
|------|------|------|
| [BRAND.md](BRAND.md) | 브랜드 아이덴티티 | 앱 이름, 슬로건, 브랜드 가치 |
| [UI_DESIGN.md](UI_DESIGN.md) | UI 설계 문서 | 사이드바, Discover 탭, AI 요약 UI |
| [IMAGE_CACHING.md](IMAGE_CACHING.md) | 이미지 캐싱 | 캐시 전략, 디렉토리 구조 |

### API 문서 (`api/` 폴더)

| 파일 | API | 상태 |
|------|-----|------|
| [api/SETUP_GEMINI.md](api/SETUP_GEMINI.md) | Google Gemini | 현재 사용 |
| [api/SETUP_OLLAMA.md](api/SETUP_OLLAMA.md) | Ollama | 레거시 (v2.1.0 이후 미사용) |
| [api/AX4_ANALYSIS.md](api/AX4_ANALYSIS.md) | SKT A.X 4.0 | 현재 사용 |

→ 자세한 내용은 [api/README.md](api/README.md) 참조

### 테스트 문서 (`tests/` 폴더)

| 파일 | 챕터 | 상태 |
|------|------|------|
| [tests/v2.3.0.md](tests/v2.3.0.md) | SponsorBlock + 기능 다듬기 | ✅ 완료 (7/8) |
| [tests/v2.4.0.md](tests/v2.4.0.md) | SwiftData + A.X 4.0 통합 | ⬜ |
| [tests/v2.5.0.md](tests/v2.5.0.md) | SQLite DB + 자막 캐싱 | ⬜ 진행 중 |
| [tests/v2.5.1.md](tests/v2.5.1.md) | AI 요약 + 챕터 생성 | ⬜ 대기 |
| [tests/v2.5.2.md](tests/v2.5.2.md) | AI 팟캐스트 생성 | ⬜ 대기 |
| [tests/v2.5.3.md](tests/v2.5.3.md) | 트랜스크립트 Q&A | ⬜ 대기 |
| [tests/v2.5.4.md](tests/v2.5.4.md) | 마인드맵 생성 | ⬜ 대기 |
| [tests/v2.5.5.md](tests/v2.5.5.md) | UI 통합 | ⬜ 대기 |
| [tests/v2.5.6.md](tests/v2.5.6.md) | 마이그레이션 + 최종 테스트 | ⬜ 대기 |

→ 자세한 내용은 [tests/README.md](tests/README.md) 참조

### 변경 이력

| 파일 | 목적 | 설명 |
|------|------|------|
| [CHANGELOG.md](CHANGELOG.md) | 버전별 변경 이력 | 모든 버전의 변경 사항 |

---

## 버전 진행 규칙

**핵심**: 다음 버전으로 진행하려면 현재 버전의 모든 테스트를 완료해야 한다.

1. 코드 구현 완료 → `PLAN.md` + `TODO.md` 업데이트
2. 테스트 케이스 작성 → `docs/tests/v{버전}.md` 생성
3. 테스트 실행 → 사용자가 수동으로 테스트 수행
4. 테스트 결과 기록 → `docs/tests/v{버전}.md`에 결과 표시
5. 모든 테스트 통과 → 다음 버전 진행 가능
6. 테스트 미완료 → 다음 버전 진행 불가 (에이전트가 고지)

---

## 문서 업데이트 규칙

- 변경 사항이 생기면 반드시 관련 파일을 업데이트한다
- 코드 수정과 문서 수정은 같은 작업 단위로 한다
- 문서 업데이트 없이 코드만 수정하지 않는다

---

## 문서 작성 언어

- 모든 문서는 한국어로 작성한다
- 소스 코드 주석도 한국어를 사용한다
- 기술 용어는 영어 그대로 사용할 수 있다
