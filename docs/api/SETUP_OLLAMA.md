> ⚠️ **v2.1.0 마이그레이션 완료**
>
> TubeKeep v2.1.0부터 Ollama 대신 **Google Gemini API**를 사용합니다.
> 더 이상 Ollama 설치가 필요하지 않습니다. 설정 창에서 Gemini API 키를 입력하세요.
>
> 새 설정 가이드는 [`SETUP_GEMINI.md`](./SETUP_GEMINI.md)를 참조하세요.
>
> ---
>
> 아래 내용은 v2.0.0 이하 레거시 문서입니다.

# Ollama Setup (Legacy) — AI 요약 & 자동 태깅

TubeKeep v2.0.0+의 AI 요약(SummarizationService)과 자동 태깅(TaggingService)은 **Ollama** 로컬 LLM을 통해 동작합니다.

## 설치

```bash
# 1. Ollama 설치 (macOS)
brew install ollama

# 2. Ollama 서비스 시작
brew services start ollama

# 3. llama3.2 모델 다운로드 (약 2GB)
ollama pull llama3.2
```

## 실행 확인

```bash
# Ollama 서비스 상태 확인
ollama list
# → NAME           ID    SIZE    MODIFIED
# → llama3.2:latest  ...  2.0GB  ...

# 간단한 테스트
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Say hello",
  "stream": false
}'
# → {"response":"Hello!","done":true,...}
```

## 동작 원리

### AI 요약
1. Library 좌클릭 메뉴 / Discover 카드 / 다운로더 창 → "AI 요약" 버튼
2. `SummarizationService`가 yt-dlp로 자막(.vtt/.srt)을 다운로드
3. 자막 텍스트를 Ollama `llama3.2`에 전달 → 개요 + 핵심 포인트 추출
4. 결과를 `LibraryItem.summary`에 저장 (디스크 영속화)

> 자막이 없는 영상은 요약할 수 없습니다.
> Library에 저장된 영상은 오프라인에서도 로컬 자막 파일로 요약 가능합니다.

### 자동 태깅
1. 다운로드 완료 시 `TaggingService`가 title + channel을 분석
2. Ollama `llama3.2`에 10개 카테고리 중 분류 요청
3. Ollama 실패 시 키워드 기반 fallback 분류
4. 결과를 `LibraryItem.tags`에 저장

## 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| "연결 거부" 오류 | Ollama 서비스 미실행 | `brew services start ollama` |
| "model not found" | 모델 미다운로드 | `ollama pull llama3.2` |
| 요약 결과 없음 | 영상에 자막 없음 | 자막이 있는 영상으로 테스트 |
| 태깅 안 됨 | Ollama 미설치 | 태깅은 키워드 fallback으로 동작 |

## 필수 사항

- Ollama는 **선택 사항**입니다. 설치하지 않아도 Discover 탐색, 다운로드, 보관함 등 모든 기본 기능은 정상 동작합니다.
- AI 요약이 동작하지 않아도 다른 기능에 영향을 주지 않습니다.
- Ollama는 로컬에서만 실행되며, 외부 API 호출이 없습니다.
