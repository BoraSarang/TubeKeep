# AGENTS.md — AI 에이전트 작업 가이드

**제작자**: BoRaSaRang · **EMail**: borasarang@gmail.com

이 프로젝트는 AI 에이전트가 코드를 이해하고 수정할 수 있도록 5개의 문서 파일로 관리됩니다.
아래 규칙을 따라 각 파일을 유지보수하세요.

---

## 한글 맞춤법 규칙

소스 코드와 문서에서 한글을 사용할 때 아래 맞춤법을 반드시 준수한다.

### 띄어쓰기

| 규칙 | 예시 | 오류 |
|------|------|------|
| 조사(은/는, 이/가, 을/를, 에/에서, 의, 도, 만, 까지 등)는 앞말에 붙인다 | `URL을 입력하세요`, `버튼을 누르세요` | ❌ `URL 을 입력하세요` |
| 관형사형 `-ㄹ` 뒤에는 띄어 쓴다 | `할 수 있습니다`, `볼 수 있습니다` | ❌ `할수 있습니다` |
| 의존명사(수, 데, 것, 때, 후, 중 등)는 앞말에 붙인다 | `테스트 중입니다`, `진행 중` | ❌ `테스트 중 입니다` |
| 서술어 `-아/어서`는 앞말에 붙인다 | `입력해 주세요`, `선택해 보세요` | ❌ `입력해 주세요` (OK), ❌ `입력 해 주세요` |
| 접미사 `-(이)다/-(으)ㅂ니다/-(스)ㅂ니다`는 앞말에 붙인다 | `가져갑니다`, `확인합니다` | ❌ `가져 갑니다` |

### 사이시옷

| 규칙 | 예시 | 오류 |
|------|------|------|
| 받침 뒤에 모음으로 시작하는 접미사가 오면 시옷(ㅅ)을 지운다 | `짓이 → 짓 + 이 → 지지` (단, 고유명사/외래어 제외) | — |
| 받침 뒤에 자음으로 시작하는 접미사가 오면 시옷을 유지한다 | `깃발 → 깃발` (변화 없음) | — |

### 외래어 표기법

| 규칙 | 올바른 표기 | 틀린 표기 |
|------|-------------|-----------|
| 외래어는 한국어 발음에 맞춰 표기한다 | `포맷(format)`, `버튼(button)` | ❌ `프로맷`, `바톤` |
| 축약어는 그대로 표기한다 | `URL`, `API`, `MP3` | — |

### 기타

| 규칙 | 예시 | 오류 |
|------|------|------|
| 숫자와 단위 사이에는 띄어 쓴다 | `3개`, `10초`, `2시간` | ❌ `3 개`, `10 초` |
| 접속사 앞에는 띄어 쓴다 | `그리고`, `하지만`, `그래서` | — |
| 혼동하기 쉬운 표현 | `되어 → 되어` (표준), `되여 → ❌` | — |

---

## 응답 언어 규칙

**핵심 규칙**: 에이전트는 사용자와의 모든 대화, 분석, 설명, 요약을 반드시 **한국어**로 표시한다. 내부 사고 과정(thought/reasoning) 포함 모든 출력은 한국어로 작성한다.

| 상황 | 올바른 예 | 잘못된 예 |
|------|-----------|-----------|
| 코드 분석 결과 | "이 함수는 자막을 DB에 저장합니다." | "This function saves subtitles to DB." |
| 에러 원인 설명 | "sqlite3_step 반환값 체크가 잘못되었습니다." | "The sqlite3_step return value check is wrong." |
| 변경 사항 요약 | "프롬프트에 한국어 강제 규칙을 추가했습니다." | "Added Korean enforcement rule to prompt." |
| 기술적 설명 | "security-scoped bookmark는 파일 접근 권한을 유지합니다." | "Security-scoped bookmark maintains file access." |
| 내부 사고 과정 | "앱 실행 후 권한 팝업 확인이 필요합니다." | "Let me wait for the user to check the permission dialog." |

**예외**: 코드 내 주석, 변수명, 함수명 등 소스 코드는 영어 사용 가능

---

## 문서 분류 및 파일 목록

### 핵심 문서 (반드시 유지보수)

| 파일 | 목적 | 포함 내용 |
|------|------|-----------|
| `PRD.md` | 제품 요구사항 정의 | 사용자 스토리, 기능 명세, 제약 조건 |
| `DESIGN.md` | 기술 설계 문서 | 아키텍처, 데이터 흐름, 컴포넌트 설계, 코드 구조 |
| `PLAN.md` | 구현 일정/계획 | 완료된 작업, 진행 중 작업, 향후 계획 |
| `TODO.md` | 작업 추적 목록 | 세부 할 일 목록 (상태: pending/in_progress/completed/cancelled) |
| `AGENTS.md` | AI 에이전트 가이드 | 파일 설명, 업데이트 규칙, 작업 지침 |

### 참조 문서

| 파일 | 목적 | 포함 내용 |
|------|------|-----------|
| `BRAND.md` | 브랜드 아이덴티티 | 앱 이름, 슬로건, 브랜드 가치, 무드 |
| `UI_DESIGN.md` | UI 설계 문서 | 사이드바 네비게이션, Discover 탭, AI 요약 UI |
| `IMAGE_CACHING.md` | 이미지 캐싱 아키텍처 | 캐시 전략, 디렉토리 구조 |

### API 문서 (`api/` 폴더)

| 파일 | API | 상태 |
|------|-----|------|
| `api/SETUP_GEMINI.md` | Google Gemini | 현재 사용 |
| `api/SETUP_OLLAMA.md` | Ollama | 레거시 (v2.1.0 이후 미사용) |
| `api/AX4_ANALYSIS.md` | SKT A.X 4.0 | 현재 사용 |

### 테스트 문서 (`tests/` 폴더)

| 파일 | 챕터 | 상태 |
|------|------|------|
| `tests/v2.3.0.md` | SponsorBlock + 기능 다듬기 | ✅ 완료 (7/8) |
| `tests/v2.4.0.md` | SwiftData + A.X 4.0 통합 | ⬜ |
| `tests/v2.5.0.md` | SQLite DB + 자막 캐싱 | ⬜ 진행 중 |
| `tests/v2.5.1.md` | AI 요약 + 챕터 생성 | ⬜ 대기 |
| `tests/v2.5.2.md` | AI 팟캐스트 생성 | ⬜ 대기 |
| `tests/v2.5.3.md` | 트랜스크립트 Q&A | ⬜ 대기 |
| `tests/v2.5.4.md` | 마인드맵 생성 | ⬜ 대기 |
| `tests/v2.5.5.md` | UI 통합 | ⬜ 대기 |
| `tests/v2.5.6.md` | 마이그레이션 + 최종 테스트 | ⬜ 대기 |

### 변경 이력

| 파일 | 목적 | 포함 내용 |
|------|------|-----------|
| `CHANGELOG.md` | 버전별 변경 이력 | 모든 버전의 변경 사항 기록 |

### 계획 문서 (`plans/` 폴더)

| 파일 | 목적 | 포함 내용 |
|------|------|-----------|
| `plans/PLAN_v{버전}.md` | 버전별 상세 계획 | 아키텍처, 구현 단계, State/Action 설계, 테스트 계획 |

---

## 계획 문서 관리 규칙

**핵심 규칙**: 각 버전의 상세 계획은 `docs/plans/` 폴더에 별도 파일로 관리한다.

### 파일 생성 규칙

1. **생성 시점**: 새 버전(v2.5.x) 구현을 시작할 때 상세 계획 문서 생성
2. **파일명 형식**: `PLAN_v{버전}.md` (예: `PLAN_v2.5.2.md`)
3. **저장 위치**: `docs/plans/`
4. **필수 섹션**:
   - 개요 (기능 설명)
   - 결정 사항 (TTS 엔진, 저장 위치 등)
   - 아키텍처 (데이터 흐름 다이어그램)
   - 구현 단계 (T-번호, 작업명, 우선순위)
   - State/Action 설계 (TCA Reducer 확장)
   - UI 통합 (기존 UI 어디에 추가할지)
   - 테스트 계획 (TC-번호, 테스트명, 내용)

### 참조 규칙

1. **PLAN.md**: `plans/` 폴더의 파일을 참조하는 링크만 포함
   ```markdown
   #### 챕터 3: AI 팟캐스트 생성 (v2.5.2)
   **상세 계획**: `docs/plans/PLAN_v2.5.2.md` 참조
   ```
2. **TODO.md**: 각 작업 항목에 계획 문서 참조 불필요 (T-번호로 식별)
3. **DESIGN.md**: 서비스/모델 설명 시 계획 문서 참조 불필요

### 유지보수 규칙

1. **계획 변경 시**: `docs/plans/PLAN_v{버전}.md` 파일 직접 수정
2. **PLAN.md 업데이트**: 계획 변경 사항을 PLAN.md에 반영 (상세 내용은 plans 폴더에)
3. **버전 완료 시**: 완료된 계획 문서를 `docs/plans/archive/`로 이동 (선택사항)

### 예시

```
docs/
├── plans/
│   ├── PLAN_v2.5.2.md    # AI 팟캐스트 생성 상세 계획
│   ├── PLAN_v2.5.3.md    # 트랜스크립트 Q&A 상세 계획
│   └── archive/          # 완료된 버전 보관 (선택)
├── tests/
│   ├── v2.5.2.md
│   └── v2.5.3.md
├── PLAN.md               # 전체 개요 + plans 참조
├── TODO.md               # 작업 추적
└── ...
```

---

## 버전 진행 규칙 (테스트 필수)

**핵심 규칙**: 다음 버전으로 진행하려면 현재 버전의 모든 테스트 케이스를 완료해야 한다.

### 테스트 케이스 관리

1. **테스트 케이스 위치**: `docs/tests/v{버전}.md`
2. **파일 형식**: 각 버전마다 하나의 마크다운 파일
3. **내용**: 버전 번호, 빌드 방법, 전제조건, 테스트 절차, 기대 결과, 결과 요약표

### 버전 진행 절차

1. **코드 구현 완료** → `PLAN.md` + `TODO.md` 업데이트
2. **테스트 케이스 작성** → `docs/tests/v{버전}.md` 생성
3. **테스트 실행** → 사용자가 수동으로 테스트 수행
4. **테스트 결과 기록** → `docs/tests/v{버전}.md`에 결과 표시 (✅/⬜)
5. **모든 테스트 통과** → 다음 버전 진행 가능
6. **테스트 미완료** → 다음 버전 진행 불가 (에이전트가 반드시 고지)

### 에이전트 의무

- **버전 진행 전 확인**: 사용자가 다음 버전 진행을 요청하면, 현재 버전의 테스트 케이스 완료 여부를 반드시 확인
- **미완료 시 고지**: 테스트가 모두 완료되지 않았으면 "현재 버전의 테스트가 완료되지 않았습니다. 다음 버전으로 진행하려면 모든 테스트를 통과해야 합니다." 메시지 표시
- **강제 진행 금지**: 테스트 미완료 상태에서 코드 수정이나 새 버전 구현을 시작하지 않음
- **예외 상황**: 사용자가 명시적으로 "테스트 스킵하고 진행해"라고 말한 경우에만 예외

### 테스트 케이스 작성 지침

```markdown
# v{버전} 테스트 케이스 — {챕터 제목}

**빌드**: `bash build_and_run.sh debug`
**대상**: TubeKeep.app v{버전}
**전제조건**: {이전 버전 테스트 완료 여부}

---

## TC-{번호}: {테스트명}

| 항목 | 내용 |
|------|------|
| **전제조건** | {테스트에 필요한 사전 조건} |
| **테스트 URL** | {테스트에 사용할 URL} |

**절차:**
1. {단계별 절차}

**기대 결과:**
- [ ] {기대 결과 1}
- [ ] {기대 결과 2}

---

## 테스트 결과 요약

| TC | 테스트명 | 결과 |
|----|---------|------|
| TC-{번호} | {테스트명} | ⬜ |

**최종 결과: 0/N 통과**
```

---

## 파일 관리 규칙

### 1. 변경 사항이 생기면 반드시 관련 파일을 업데이트하라

- **코드 구조 변경** (새 파일 추가, 리팩토링) → `DESIGN.md` 업데이트
- **기능 추가/변경** (새 UI, 새 동작) → `PRD.md` + `DESIGN.md` 업데이트
- **작업 완료/진행 상황 변경** → `PLAN.md` + `TODO.md` 업데이트
- **에이전트 관련 규칙 변경** → `AGENTS.md` 업데이트
- **버전 완료/테스트** → `docs/tests/v{버전}.md` 작성/업데이트

### 2. 업데이트 타이밍

- **즉시 업데이트**: 기능 구현 완료 시, 리팩토링 완료 시
- **함께 업데이트**: 코드 수정과 문서 수정은 같은 작업 단위로
- **누락 금지**: 문서 업데이트 없이 코드만 수정하지 말 것
- **버전 자동 업데이트**: `PLAN.md`에서 버전이 확정되면 `Info.plist`의 `CFBundleShortVersionString`과 `CFBundleVersion`을 즉시 업데이트한다

### 3. 각 파일의 역할과 작성 지침

#### PRD.md
- 제품의 `무엇`을 정의 (기술적 구현 제외)
- 사용자 관점의 기능 설명
- 우선순위와 제약 조건

#### DESIGN.md
- 제품의 `어떻게`를 정의
- 구체적인 기술 설계: 아키텍처, 컴포넌트, 데이터 흐름
- 코드 구조와 파일 매핑
- TCA Reducer 구조, State/Action 정의

#### PLAN.md
- 작업의 `언제/무엇을` 정의
- 완료된 기능 목록
- 진행 중인 작업 (in_progress)
- 향후 계획 (pending)
- 마일스톤

#### TODO.md
- 개별 작업 단위 추적
- 각 작업: 설명 + 상태(pending/in_progress/completed/cancelled)
- 작업 우선순위 (high/medium/low)
- 작업 완료 조건

---

## 작업 시작 전 확인사항

1. `AGENTS.md` 읽기 — 작업 규칙 숙지
2. `PRD.md` 읽기 — 제품 요구사항 이해
3. `DESIGN.md` 읽기 — 기존 설계 이해
4. `PLAN.md` 읽기 — 현재 진행 상황 확인
5. `TODO.md` 읽기 — 구체적인 작업 목록 확인
6. **`docs/tests/v{현재버전}.md` 읽기 — 테스트 완료 여부 확인** (버전 진행 시 필수)

## 작업 완료 후 확인사항

1. 변경된 코드가 문서와 일치하는가?
2. `PRD.md`에 반영되지 않은 새 기능이 있는가?
3. `DESIGN.md`에 반영되지 않은 설계 변경이 있는가?
4. `PLAN.md`의 진행 상태가 최신인가?
5. `TODO.md`의 작업 상태가 최신인가?
6. **`docs/tests/v{버전}.md`에 테스트 케이스가 작성되었는가?** (버전 완료 시 필수)

---

## 공동 작업 규칙

- 한 번에 하나의 작업만 `in_progress`로 설정
- 작업이 완료되면 `completed`로 표시하고 관련 파일 업데이트
- 작업이 막히면 `in_progress` 유지 + `TODO.md`에 블로커 명시
- 다른 에이전트가 작업 중인 파일을 수정하지 말 것
- 에이전트와의 모든 대화는 **한국어**로 진행한다

### 질문-응답-수정 워크플로

사용자가 "~할 수 있나?", "~는 안 되나?" 등 의문문으로 질문하면:

1. **즉시 코드 수정하지 말 것** — 먼저 가능 여부, 접근법, 장단점, 영향 범위를 설명
2. 사용자가 "그렇게 해" / "해줘" / "적용해" 등 명확한 승인을 한 후에만 코드 수정
3. 코드 수정 후에는 별도 설명 없이 결과만 간략히 전달
4. 같은 주제로 반복 질문-응답 사이클을 돌지 말 것 — 첫 응답에 모든 옵션과 판단 근거를 종합적으로 제시

### 플랜 모드 vs 빌드 모드

**핵심 규칙**: 사용자가 빌드/수정/실행을 명시적으로 지시할 때만 파일을 수정한다.

| 모드 | 조건 | 파일 쓰기 허용? |
|------|------|----------------|
| **플랜 모드** (기본) | 사용자가 의견/질문/아이디어만 말함 | ❌ 절대 금지 |
| **빌드 모드** | 사용자가 "빌드해", "수정해", "재 실행해", "진행해", "해줘", "적용해" 등 실행 명령을 말함 | ✅ 허용 |

- 플랜 모드에서는 **어떤 파일도 생성하거나 수정하지 말 것** (코드, 문서, 설정 파일 모두 포함)
- 사용자가 한마디 할 때마다 코드를 수정하지 말 것 — 하나의 작업을 여러 번 수정하지 않도록
- 빌드 모드로 전환되기 전까지는 분석/설명/제안만 할 것

## 빌드 & 실행 규칙

- 일반 빌드: `bash build_and_run.sh debug` — 빠른增量 빌드
- 클린 빌드 필요 시: `bash build_and_run.sh debug --clean` — `swift package clean` 실행
- 사용자가 "빌드해" / "재실행해" → 일반 빌드 (`--clean` 없이)
- 사용자가 "클린빌드" / "클린 빌드" → `--clean` 옵션 추가
- 절대 빌드 없이 기존 바이너리만 재실행하지 말 것

## 디버그 로그 규칙

**핵심 규칙**: `print()`를 사용하지 말고 반드시 `DebugLogManager.shared?.append()`를 사용한다.

```swift
// ❌ 잘못된 예
print("[ERROR] Something failed")

// ✅ 올바른 예
#if DEBUG
Task { @MainActor in
    DebugLogManager.shared?.append("[ERROR] Something failed")
}
#endif
```

- `print()`는 콘솔에만 출력되고 앱의 디버그 로그 창에 표시되지 않음
- `DebugLogManager.shared?.append()`는 라이브러리/다운로더/채널 디버그 로그 창에 표시됨
- `#if DEBUG` 블록 안에서 호출할 것 (릴리즈 빌드에서 제외)

## 문제 해결 원칙

### 1. 최종 목표를 먼저 정의하라
- "이게 안 된다"가 아니라 "이걸 이루려면 어떤 방법들이 있는가"를 먼저 생각
- 실행 불가능한 이유를 나열하지 말고, 가능한 모든 접근법을 제시
- 각 접근법의 장단점을 설명하고 추천안을 제시한 후 사용자에게 선택권을 줘라

### 2. 외부 의존성은 번들에 포함하라
- yt-dlp, ffmpeg 등 외부 바이너리는 사용자 PATH에 의존하지 말고 `.app/Contents/Resources`에 포함
- 사용자가 "설치하라"는 메시지를 보게 하지 말 것
- 의존성 문제는 구현 전에 미리 파악하여 설계 단계에서 해결할 것

### 3. 근본 원인을 해결하라 (우회 금지)
- `--merge-output-format` 같은 부분 해결책으로 때우지 말 것
- "mp4가 안 나오면 번들에 ffmpeg 포함 + remux-video" 같은 근본 해결을 해라
- 경고 메시지(ffmpeg missing 등)는 즉시 캐치하고 근본적으로 해결해야 할 문제로 간주

### 4. 하나의 답만 제시하지 말고 여러 방법을 제시하라
- 문제 해결 시 최소 2~3가지 접근법을 검토
- 각 방법의 장단점, 난이도, 영향 범위를 함께 전달
- 사용자가 선택할 수 있도록 "방안 A, B, C" 형태로 제시

### 5. 사용자의 최종 경험을 기준으로 판단하라
- "사용자가 앱을 설치하고 나서 첫 실행 때 어떤 경험을 하는가?"
- 중간 과정(설치, 설정, 의존성)은 사용자에게 보이지 않게 해라
- 기능 하나를 추가할 때마다 "이게 사용자 입장에서 매끄러운가?"를 자문

## 공통 이슈 & 해결 기록

### 클립보드 감시 — 라이브러리 창 열려 있을 때
- `AppDelegate.swift` 라인 468: `mainVisible` 체크 후 다운로더 창을 열고 `autoFetchInfo` 전송
- 라이브러리 창 닫힘 → NSPanel 팝오버
- 라이브러리 창 열림 → 다운로더 창 오픈 후 autoFetch (수정 완료)

### 라이브러리 데이터 저장 race condition
- `AppReducer.downloadCompleted`에서 `addItem` + `loadFromDisk`를 순차적으로 실행
- UserDefaults는 atomic하지만 TCA effect는 비동기 → 순차 보장 필요

### FixedWidthWindowController dealloc 문제
- 반드시 `AppDelegate`의 프로퍼티(`mainWindowController`)에 저장할 것
- 로컬 변수(`let _ =`)에 할당하면 delegate 해제되어 width 고정 실패

---

### 6. v1.1.0 전체 완료 (10건, 2026-07-14)

**v1.1.0 Medium 5건:**
- T-118: `LibrarySidebarView` — 채널 목록 하단 `+ 채널 추가` 버튼
- T-117: `LibrarySidebarView` — 채널 ForEach `.onMove` + UserDefaults `channelOrder`
- T-116: `LibraryReducer` — `downloadSubtitles`/`subtitleResult` 액션; Grid/List 좌클릭 메뉴 "자막 다운로드"
- T-111: `LibraryGridCell` — `onHover` + `.popover` 360×203 확대 미리보기
- T-112: `LibraryReducer` — `selectedIds` + selection actions; `LeftClickMenu` Cmd+클릭 토글; selectionBar

**v1.1.0 High 5건:**
- T-110: `LibrarySidebarView` — 하단 `출력 폴더 열기` 버튼 (store.settings.outputDirectory → NSWorkspace)
- T-113: `Info.plist` — `CFBundleURLTypes` → `tubekeep://` scheme; `AppDelegate.handleGetURLEvent` + `HomeReducer.setURL`
- T-119: `LibraryItem.uploadDate: Date?` 추가; `LibrarySortOrder`에 `uploadDateDesc`/`uploadDateAsc`; 채널 선택 시 기본 정렬=uploadDate; `parseUploadDate()`; Grid/List UI 날짜 표시 개선
- T-115: `DownloadQueueReducer` — `loadQueue`/`saveQueue`/`itemsLoaded` 액션; UserDefaults `downloadQueue` 키; 재시작 시 downloading/paused → pending 리셋
- T-114: `AppDelegate.startChannelUpdateCheck` (30분 타이머) → `ChannelFetchService.fetchAllVideos` → `ChannelDownloadCache.loadDownloadedIDs` + `loadSeenVideoIds`와 비교 → 새 영상 ID를 `channelsNewVideos`에 저장 + StatusBar badge (채널 수) + UNUserNotification
  - 뱃지 클릭 → 채널 다운로더 창 오픈 (첫 새 영상 채널 자동 선택), badgeReset
  - `channelsSeenVideoIds`: 사용자가 확인한 영상 ID 저장 (채널 선택/새로고침 시 `newIds→seenIds` 이동) → 다운로드 안 해도 재감지 안 됨
  - 다운로드 완료 시 `removeSeenVideoIds` 호출
  - 체크 진행률: 상태바 "업데이트 확인 중 (N/M) — 채널명" 표시 + DEBUG 로그(channelLogManager)
  - 채널 리스트 `ChannelRow`: 새 영상 채널에 빨간 ● 배지
  - `ChannelContentView.channelHeader`: 최신 업로드 날짜 + "새 영상 N개 — 새로고침 필요" 배너
  - 채널 선택 시 `ChannelDownloadCache.saveSeenVideoIds` + `clearNewVideoIds` 호출

**새 상수:** `Constants.channelOrderKey`, `Constants.downloadQueueKey`

**새 서비스 메서드:** `LibraryCacheService.removeItems(ids:)`, `StatusBarReducer.setBadgeCount`

**변경 사항 요약:**
- **T-118**: `LibrarySidebarView` — 채널 목록 하단 `+ 채널 추가` 버튼 추가
- **T-117**: `LibrarySidebarView` — 채널 ForEach에 `.onMove` + UserDefaults `channelOrder` 키로 순서 저장
- **T-116**: `LibraryReducer` — `downloadSubtitles`/`subtitleResult` 액션 추가; `LibraryGridCell`/`LibraryListRow` — 좌클릭 메뉴에 "자막 다운로드" 추가
- **T-111**: `LibraryGridCell` — 썸네일에 `.onHover` + `.popover`로 360×203 확대 미리보기
- **T-112**: `LibraryReducer` — `selectedIds`, `toggleSelection`/`selectAll`/`clearSelection`/`removeSelected` 추가; `LeftClickMenu` — `onToggleSelection` closure, Cmd+클릭 시 토글; Grid/List — selectionBar (N개 선택됨 / 전체 선택 / 선택 해제 / 선택 삭제)

**새 상수:** `Constants.channelOrderKey`

**관련 서비스:** `LibraryCacheService.removeItems(ids:)` 추가

### 7. v1.2.0 — 채널 업데이트 알림 개선 + 디스크 사용량 (2026-07-16)

**T-114 보강:**
- `seenVideoIds` 도입: 채널 선택/새로고침 시 `newIds`를 `seenIds`로 이동 → 다운로드 안 해도 재감지 안 됨
- 상태바 진행률: "업데이트 확인 중 (N/M)" → `statusBar.updateStatusText` 액션 추가
- DEBUG 로그: `channelLogManager` → `libraryLogManager` (메인 TubeKeep 창에 표시)
- `openVideoDownloaderWindow`: `MainView` → `VideoDownloadView`로 수정
- StatusBar badge: 10초 autoReset 제거, 사용자 클릭 시까지 유지

**디스크 사용량:**
- `LibraryCacheService.calculateDiskUsage()` — `outputDirectory` + 캐시 디렉토리 FileManager.enumerator 합산
- `LibraryReducer`: `diskUsageBytes: Int64` State + `.calculateDiskUsage` / `.diskUsageUpdated` 액션
- AppReducer: downloadCompleted, removeSelected, removeItemsByChannel 후 `.library(.calculateDiskUsage)` 전송
- `LibrarySidebarView` 하단: `[폴더] Finder에서 보기  12.3 GB  ↻` — ↻ 버튼으로 수동 새로고침
- `formatBytes()` — `ByteCountFormatter` 포맷팅
- onAppear 시에도 1회 호출

**새 서비스 메서드:** `LibraryCacheService.calculateDiskUsage()` (static)

### 8. 반복 실수 방지 — 변경 전 3단계 검증
같은 유형의 실수가 반복되지 않도록 아래 규칙을 반드시 지킨다:

1. **기존 구현 확인**: 새 기능/수정을 하기 전에 반드시 동일한 기능의 기존 구현을 먼저 찾아서 읽는다
   - 예: 툴바 버튼 추가 시 `BatchDownloadView`의 툴바를 먼저 확인
2. **요청-수정 체크리스트**: 수정 완료 후 "사용자가 요청한 것"과 "내가 만든 것"을 항목별로 대조한다
   - 기능 A? ✅ / 기능 B? ❌ → 누락 발견 즉시 추가
3. **데이터로 검증, 추측 금지**: 원인 분석 시 "아마 ~일 것이다"로 끝내지 말고 실제 데이터/코드 경로를 추적해서 확인한다
   - 예: 타임아웃 원인을 "채널 영상이 많아서"라고 말하려면 먼저 실제 영상 수를 확인
   - 예: 권한 문제 원인을 "캐시 문제"라고 말하려면 먼저 어떤 파일 작업이 일어나는지 전부 추적

### 9. CMD+V/C/X/A 단축키 동작 — 이벤트 모니터 필요
`LSUIElement = true` 에이전트 앱에서는 macOS가 자동으로 메인 메뉴 바를 생성하지 않는다. 따라서 CMD+V(붙여넣기), CMD+C(복사), CMD+X(잘라내기), CMD+A(모두선택) 등 표준 편집 단축키가 동작하지 않는다.

**증상**: CMD+V 시 "띠띠띠띠" 경고음 발생, 오른쪽 클릭 붙여넣기는 정상 동작

**원인**: `NSApplication`이 메인 메뉴 바에서 `keyEquivalent`에 해당하는 메뉴 항목을 찾지 못하면 시스템 경고음을 재생한다.

**해결**: `AppDelegate.applicationDidFinishLaunching`에서 `NSEvent.addLocalMonitorForEvents`로 키 이벤트를 직접 가로채 `NSApp.sendAction`을 통해 first responder에게 전달한다.

**⚠️ 중요: `event.keyCode`를 사용해야 한다.** 한글 키보드 레이아웃에서는 `event.charactersIgnoringModifiers`가 한글 문자를 반환한다 (예: `c`→`ㅍ`, `v`→`ㅇ`). `keyCode`는 레이어와 관계없이 고정되어 있다.

```swift
// AppDelegate.swift — applicationDidFinishLaunching 내
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    if event.modifierFlags.contains(.command) {
        switch event.keyCode {
        case 49: // ,
            self.openSettingsWindow()
            return nil
        case 7:  // x
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            return nil
        case 8:  // c
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            return nil
        case 9:  // v
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            return nil
        case 0:  // a
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            return nil
        default: break
        }
    }
    return event
}
```

**키 코드 참조**: `0`=A, `7`=X, `8`=C, `9`=V, `49`=,(쉼표)

**참고**: SwiftUI의 `.commands` 수정자는 `LSUIElement = true` 앱에서 안정적으로 동작하지 않으므로 이벤트 모니터 방식을 사용한다.

### 10. AI 요약/자막 DB 캐싱 패턴

v2.5.0부터 AI 요약과 자막은 SQLite DB에만 저장된다.

**AI 요약 캐싱**:
- `SummarizationService.summarizeVideo()`가 API 폴백 체인 진입 전에 `DatabaseManager.shared.loadVideoAIData()`로 기존 요약 확인
- 요약 생성 후 `DatabaseManager.shared.updateSummary()`로 SQLite 저장 + SwiftData 저장 (다운로드한 영상만)
- `LibraryReducer.showSummary`에서 `item.summary`를 먼저 확인하여 중복 API 호출 방지

**자막 가용성 확인**:
- `LibraryReducer.hasSubtitles(for:)`가 파일시스템 대신 SQLite에서 transcript 존재 여부 확인
- `LibraryItem.id`는 YouTube videoId를 사용하므로 DB 키와 일치

**데이터 흐름**:
```
자막 다운로드 → 임시 파일 → 파싱 → DatabaseManager.updateTranscript() → 임시 파일 삭제
AI 요약 요청 → DB 캐시 확인 → 있으면 즉시 반환 / 없으면 API 호출 → DatabaseManager.updateSummary()
```
