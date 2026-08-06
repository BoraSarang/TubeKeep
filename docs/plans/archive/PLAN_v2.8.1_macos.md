# PLAN v2.8.1 — 에이전트 규칙(v2.1) 적용 + 개발 표준화 🔄

> **버전**: v2.8.1
> **목표**: 공통 AGENTS.md v2.1.0-common 업데이트를 읽고, TubeKeep(macOS 단일 플랫폼)에 실질적으로 적용할 수 있는 항목만 반영
> **특성**: 싱글 유저 앱, macOS SwiftPM/특화(SwiftUI·TCA·SwiftData·SQLite·yt-dlp)
> **플랫폼**: [macOS]

---

## 개요

공통 `AGENTS.md`가 v2.1.0으로 확장(Safari/Firefox, 모노레포, E2E, 오프라인큐, 스토어자동화 등)되었으나
TubeKeep은 **Chrome/서버/모노레포가 아닌 macOS 네이티브 단일 앱**이라 대부분은 적용 대상 외.
본 PLAN은 적용 가치가 있는 항목만 선별한다.

### 적용 대상 선정

| 항목 | 공통 규칙 | 적용 여부 | 사유 |
|------|-----------|-----------|------|
| AI_MODELS.json | 부록 B | ✅ 신규 생성 | AI 비용/모델/프롬프트 버전/캐시정책 고정 |
| PERF/CACHE 로그 | 19장, 7.5 | ✅ 적용 | DebugLogger에 레벨 추가 + 플레이어/요약 로깅 |
| 시크릿 만료 체크 | 8.12 | ✅ 적용 | env-expiry-check.sh 생성 |
| a11y/텍스트 덤프 | 7.6.1 | ✅ 적용 | 텍스트 모델 검증용 a11y-dump.sh(macOS 적응) |
| 에러코드 E-MAC- | 8.5 | ✅ 정리 | error_message_ko.json 명세만 (런타임 로드 아님) |
| 세션 로그 | 20.4 | ✅ 적용 | /agent/session-*.md 규칙 + 작성 |
| 언어/문서우선/빌드디스패처 | 1.6/1.7/18 | ✅ 이미 준수 | 확인만 |
| Chrome/Firefox/Safari, 모노레포, E2E, 오프라인큐, 스토어 | 8.9~8.14 | ❌ 미적용 | 플랫폼 불일치 |

### 원칙(AGENTS.local.md 우선)

- **싱글 유저, 내 편의 우선** — 과도한 일반화 금지, 유지보수 가능한 선에서만 개선
- `error_message_ko.json`은 참조 명세(런타임 로드 아님) → 코드 throw-site 전면 교체는 **하지 않음**

---

## 결정 사항

1. **AI_MODELS.json** — TubeKeep 실제 사용 모델(A.X 4.0, Gemini, OpenRouter) 반영, `platforms.macos` 성능예산, `cache_policy` 포함
2. **PERF/CACHE 레벨** — `DebugLogLevel`에 `PERF`·`CACHE` case 추가 (7→9종). 포맷 유지 `[레벨] [MACOS] [CATEGORY] msg`
3. **PERF 로깅 지점** — libmpv 플레이어 cold-start(첫 프레임까지), 요약 캐시 히트 CACHE 로그
4. **env-expiry-check.sh** — `.env*`/키 소스의 `# expires:` 파싱, 30일 전 WARN / 만료 시 ERROR + bd
5. **a11y-dump.sh macos** — DebugPanel 로그 덤프 + DB/스토리지 크기 + perf 스냅샷 텍스트 3종
6. **에러코드** — error_message_ko.json을 `E-MAC-*` 규격으로 정리
7. **세션 로그** — 종료/주기 `/.agent/session-YYYY-MM-DD-macos.md` 한국어 8줄 요약

---

## 구현 단계 (T-번호)

| ID | 작업 | 우선순위 | 상태 |
|----|------|---------|------|
| T-875 | PLAN_v2.8.1 + TODO 등록 | high | 진행 중 |
| T-876 | docs/AI_MODELS.json 생성 | high | 대기 |
| T-877 | DebugLogger PERF/CACHE + 플레이어/요약 로깅 | high | 대기 |
| T-878 | scripts/env-expiry-check.sh 생성 | medium | 대기 |
| T-879 | scripts/a11y-dump.sh (macOS 적응) 생성 | medium | 대기 |
| T-880 | error_message_ko.json E-MAC- 정리 | medium | 대기 |
| T-881 | AGENTS.local.md 갱신 | high | 대기 |
| T-882 | 세션 로그 + CHANGELOG + 빌드 검증 | medium | 대기 |

---

## 테스트 계획

- **빌드**: `./build_and_run.sh debug macos` 성공
- **PERF/CACHE**: DebugPanel(`Cmd+D`)에 `[PERF]`(플레이어 cold start), `[CACHE]`(요약 히트) 로그 확인
- **스크립트**: `env-expiry-check.sh`, `a11y-dump.sh` 실행 오류 없음

## 롤백 계획

- 코드 변경은 DebugLogLevel case 추가 + 로그 2~3줄뿐 → `git revert`로 즉시 복구
- 신규 스크립트/문서는 무해(빌드 참여 안 함) → 삭제로 롤백