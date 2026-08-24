# PLAN v4.7 — 로컬 LLM(Ollama) 통합 [macOS]

## 개요
로컬 Ollama(qwen2.5:14b 등)를 모든 AI 기능의 최우선 프로바이더로 통합한다.
- API 키 불필요, 비용 0, 프라이버시(자막/전사 텍스트가 외부로 나가지 않음), 오프라인 동작
- Ollama 실패 시 기존 클라우드 체인(Gemini → OpenRouter → yTeaser/규칙기반)으로 자동 폴백 — 기존 동작 100% 유지

## 결정 사항
| 항목 | 결정 |
|------|------|
| 우선순위 | Ollama 설치·실행 중이면 항상 먼저 (사용자 확정) |
| 프로토콜 | OpenAI 호환 `POST localhost:11434/v1/chat/completions` (OpenRouterService와 동일 구조) |
| 감지 | `GET /api/tags` 타임아웃 2초, 성공 시 모델 리스트 반환 |
| 컨텍스트 | 호출 시 `options.num_ctx = 8192` 명시 (Ollama 기본 2048은 요약 15,000자에 부족) |
| 설정 저장 | UserDefaults: `ollamaEnabled`(Bool, 기본 true=감지되면 사용), `ollamaModel`(String) |
| 모델 선택 | 설정 AI 탭에서 설치된 모델 Picker + 새로고침 버튼 |

## 아키텍처

### 신설: `Services/OllamaService.swift`
```
enum OllamaError: LocalizedError { serverNotRunning, modelNotFound, apiError, ... }
struct OllamaService {
    static let defaultBaseURL = "http://localhost:11434"
    func isServerRunning() async -> Bool          // GET /api/tags (2s timeout)
    func listModels() async throws -> [String]    // /api/tags → names
    func chatCompletion(model:messages:numCtx:) async throws -> String
    func chat(prompt:systemMessage:model:) async throws -> String  // 편의 래퍼
}
```
- 요청 body: `{model, messages, stream:false, options:{num_ctx:8192}}`
- 응답 파싱: OpenAI 호환 `choices[0].message.content` (OpenRouterService와 동일)
- 타임아웃: 연결 5초 + 전체 300초 (14b 로컬 추론은 느릴 수 있음)

### 통합 지점 (2종)

**A. 공용 진입점 래핑** — QA·마인드맵·팟캐스트 자동 커버:
- `OpenRouterService.chatCompletion(prompt:apiKey:systemMessage:)` 진입 시
  Ollama 활성 && 서버 응답 && 모델 있음 → Ollama 먼저 시도, 실패 시 기존 OpenRouter 흐름
- 로그: `[AI Route] Ollama(model) 시도` / `[AI Route] Ollama 실패 → OpenRouter 폴백`

**B. 체인 단계 삽입** (`LLMChainStep` 배열 맨 앞):
| 서비스 | 삽입 스텝 | 검증 |
|--------|----------|------|
| SummarizationService | 자막→LLMPrompts.summary→SummaryParser.parse (Gemini 앞) | overview 비어있지 않음 |
| TaggingService | LLMPrompts.tag→predefinedTags 매칭 (Gemini 앞) | 결과가 predefinedTags 포함 |
| SimilarVideoService | 기존 OpenRouter/Gemini 스텝과 동일 프롬프트 | 비어있지 않음 |
| ChannelInsightService | 동일 | 비어있지 않음 |

### 설정 UI: `Features/Settings/SettingsAITab.swift`
- "로컬 Ollama" 섹션 신설:
  - 상태 행: 실행 중 ● 초록 / 꺼짐 ○ 회색 (+새로고침 버튼)
  - 모델 Picker: 설치된 모델 목록 (예: qwen2.5:14b, qwen2.5-coder:14b, moondream)
  - 안내 문구: 미설치 시 https://ollama.com 안내
- SettingsReducer에 ollamaEnabled/ollamaModel/installedModels/@State 추가

## 성능 예산
- 태깅(단문 출력): ≤10s (qwen2.5:14b 기준)
- 요약(장문 출력): ≤120s — progress 콜백으로 "로컬 AI 생성 중..." 표시
- 서버 감지: ≤2s (미설치 앱 UX 영향 없게 빠른 타임아웃)

## 에러 처리
| 코드 | 상황 | 메시지 |
|------|------|--------|
| E-MAC-AI-1001 | Ollama 서버 미실행 | 조용히 다음 체인으로 폴백 (사용자 노출 없음) |
| E-MAC-AI-1002 | 모델 로드 실패/타임아웃 | 로그 후 폴백 |

원칙: **Ollama는 폴백 사슬의 한 단계** — 실패해도 사용자 흐름이 끊기지 않는다.

## 구현 단계
- T-1210-1: PLAN 작성 + TODO 등록 ✅
- T-1210-2: OllamaService.swift 신설
- T-1210-3: OpenRouterService 공용 진입점에 Ollama 선행 로직
- T-1210-4: 체인 서비스에 Ollama 스텝 삽입 (요약·태깅 + 공용 진입점 경유 QA/마인드맵/팟캐스트/유사영상/채널인사이트)
- T-1210-5: SettingsAITab Ollama 섹션 + SettingsReducer 확장 (stored property 전환 — TCA 변경 감지)
- T-1210-6: 빌드 + 실측 검증
- **T-1210-7: 설정 탭 재구성 — "AI"→"공급자" 개명, "모델" 탭 신설**
  - SettingsTab enum: `providers = "공급자"` / `models = "모델"` (아이콘 sparkle / cube.box)
  - 공급자 탭: 로컬 AI 섹션(Ollama 헤더행+연결테스트, 하위 인덴트 leading 20) + 클라우드 섹션(Gemini/OpenRouter/yTeaser ProviderRow 스타일)
  - 모델 탭: 공급자 세그먼트(Ollama|OpenRouter) → Ollama: 설치모델 List+★기본모델+삭제, 설치 필드+추천퀵버튼+pull 진행률. OpenRouter: 모델 ID 필드
  - TTS/Whisper 섹션은 자동화 탭으로 이동 (클립보드→유휴→TTS→Whisper→행동로그)
- **T-1210-8: OllamaService 확장** — pullModel(name:onProgress:) NDJSON 스트림 파싱, deleteModel(name:)
- **T-1210-9: NVIDIA NIM 공급자 추가** — NVIDIAService 신설(OpenAI 호환 integrate.api.nvidia.com/v1), 체인 위치 Gemini 다음(Ollama→Gemini→NVIDIA→OpenRouter), 공급자 탭 클라우드 행 추가, nvidiaAPIKey 저장
- **T-1210-10: 모델 탭 4공급자 관리** — Ollama/Gemini/NVIDIA/OpenRouter 전부:
  - 모델 목록 API 자동 조회 (Ollama /api/tags · Gemini v1beta/models · NVIDIA /v1/models(키) · OpenRouter /v1/models(공개))
  - 공통 UI: 검색 필드 + 새로고침 + List(이름/ID/컨텍스트K/체크=기본모델)
  - 선택 저장: geminiModel·nvidiaModel 신설, openRouterModel·ollamaModel 기존
  - GeminiService: 하드코딩 gemini-2.0-flash → UserDefaults(geminiModel) 교체
  - OpenRouter 무료만 보기 토글(pricing.prompt=="0")

## 테스트 계획
- TC-Ollama-001: 서버 실행 중 — 설정 탭에서 qwen2.5:14b 표시·선택
- TC-Ollama-002: 다운로드 완료 → 자동 태깅이 `[AI Route] Ollama` 로그와 함께 성공
- TC-Ollama-003: 수동 요약 → Ollama 성공, provider="Ollama" 표시
- TC-Ollama-004: Ollama 종료 상태 → 기존 체인으로 폴백 (회귀 없음)

## 롤백
- `git revert` 단일 커밋. UserDefaults `ollamaEnabled=false`만으로도 즉시 비활성화.

## 성능 영향
- Ollama 미설치 환경: isServerRunning 2초 타임아웃 1회 (요약/태깅 시작 시 캐시된 결과 재사용으로 반복 감지 없음)
- Ollama 설치 환경: 클라우드 API 대비 네트워크 비용 0, 첫 모델 로드 시 수 초 소요 가능
