# Gemini API Setup — AI 요약 & 자동 태깅

TubeKeep v2.1.0+의 AI 요약(SummarizationService)과 자동 태깅(TaggingService)은
**Google Gemini API**를 통해 동작합니다.

## 설정

1. **Google AI Studio** → [aistudio.google.com](https://aistudio.google.com/apikey)에서 API 키 생성
2. TubeKeep 설정 창 열기 (⌘,)
3. "AI 요약" 섹션에서 Gemini API 키 입력 (보안 입력 필드)
4. 검증 없이 바로 저장 — 키가 없으면 요약 버튼 클릭 시 알럿 표시

## 동작 원리

### AI 요약
1. "AI 요약" 버튼 클릭 (Library/Discover/Home 3곳)
2. 키 없으면 → 알럿 ("설정 열기" / "키 발급 받기")
3. 키 있으면 → `SummarizationService`가 자막 다운로드 후 Gemini API로 요약
4. 결과를 `LibraryItem.summary`에 저장 (디스크 영속화)

### 자동 태깅
1. 다운로드 완료 시 `TaggingService`가 title + channel 분석
2. Gemini API에 10개 카테고리 중 분류 요청
3. 키 없거나 API 실패 시 키워드 기반 fallback 분류
4. 결과를 `LibraryItem.tags`에 저장

## 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| "API 키 필요" 알럿 | 키 미입력 | 설정에서 Gemini API 키 입력 |
| "할당량 초과" | 무료 티어 초과 (60 req/min) | Google AI Studio에서 할당량 확인 |
| 요약 결과 없음 | 영상에 자막 없음 | 자막이 있는 영상으로 테스트 |

## 필수 사항

- Gemini API 키는 **필수**입니다 (무료 티어 제공, 60 requests/min).
- API 키가 없으면 AI 요약/태깅이 동작하지 않으나 기본 기능(탐색, 다운로드, 보관함)은 정상 동작합니다.
- 사용하는 모델: `gemini-2.0-flash`
