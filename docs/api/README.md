# API 설정 문서

이 폴더는 TubeKeep에서 사용하는 외부 API 관련 설정 문서를 관리합니다.

---

## 파일 목록

| 파일 | API | 상태 | 설명 |
|------|-----|------|------|
| [SETUP_GEMINI.md](SETUP_GEMINI.md) | Google Gemini | 현재 사용 | AI 요약/태깅용 Gemini API 설정 |
| [SETUP_OLLAMA.md](SETUP_OLLAMA.md) | Ollama | 레거시 (v2.1.0 이후 미사용) | 로컬 LLM 설정 |
| [AX4_ANALYSIS.md](AX4_ANALYSIS.md) | SKT A.X 4.0 | 현재 사용 | A.X 4.0 API 분석 및 통합 가이드 |

---

## AI 요약 폴백 체인 (v2.4.1+)

현재 TubeKeep은 다음 순서로 AI 요약을 시도합니다:

1. **OpenRouter** (무료) → OpenAI 호환 API
2. **yTeaser** (무료) → YouTube 요약 서비스
3. **A.X 4.0** (무료) → SKT 한국어 특화 LLM
4. **Gemini** (유료) → Google Gemini API

각 단계에서 실패하면 다음 단계로 자동 폴백됩니다.

---

## AI 태깅 폴백 체인 (v2.4.1+)

1. **OpenRouter** (무료)
2. **A.X 4.0** (무료)
3. **Gemini** (유료)
4. **autoClassify** (규칙 기반 fallback)

---

## API 키 관리

| API | 키 필요 | 설정 위치 | 비용 |
|-----|---------|-----------|------|
| OpenRouter | 예 (선택) | 설정 > AI 요약 | 무료 티어 제공 |
| yTeaser | 아니오 | 기본값 | 무료 |
| A.X 4.0 | 아니오 (공개 키) | 설정 > AI 요약 | 무료 |
| Gemini | 예 (선택) | 설정 > AI 요약 | 무료 티어 제공 |

---

## 주의사항

- API 키는 `UserDefaults`에 평문 저장됩니다
- 공개 API(A.X 4.0)는 향후 유료 전환 가능성이 있습니다
- Gemini 무료 티어는 분당 60 요청 제한이 있습니다
