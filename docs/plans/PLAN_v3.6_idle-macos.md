# PLAN v3.6 — 유휴 자동화 반복 처리·팝업 안정화 (macOS)

> 플랫폼: macOS (TubeKeep 네이티브) · 작성일: 2026-08-08
> 이전 버전: v3.5 휴지통 (현재 진행 중) · 대상 로그: `2026-08-08 21:18~21:30 idle_activity.log`

## 1. 개요

유휴 자동화가 `시작 → 자막/Whisper → AI → 중단 → 15초 후 재시작`을 무한 반복하는 문제.
로그 분석 결과 **팝업 반복(증상)의 근본 원인은 자막 저장 실패**였다.

## 2. 결정 사항

1. **`DatabaseManager.updateTranscript`를 UPSERT로 변경** — 순수 `UPDATE`라서
   `video_ai_data`에 해당 `video_id` 행이 없으면 저장 0행 = 자막이 휘발됨.
   → `INSERT ... ON CONFLICT(video_id) DO UPDATE`로 변경해 최초 등록/갱신 모두 되게 함.
   (기존 `summary`/`chapters` 등 컬럼은 보존 — `INSERT OR REPLACE`는 전체 NULL화 위험 있어 사용 금지)
2. **시작/중단 팝데바운스** — 유휴가 잠깐 풀렸다 되면 `시작→중단` 알림이 15초 간격으로 반복.
   - 마지막 시작 알림/중단 알림 후 짧은 시간(예: 2분) 내 동일 종류 알림 스킵
   - `ActivityLogStore` 로그는 항상 기록(데이터 정합성 유지)
3. **`deactivationGraceSeconds` 30 → 60** — 유휴 해제 직후 60초까지는 사용 복귀로 간주하지 않는:
   Whisper 중 잠깐 마우스 흔들림 등 짧은 이벤트로 중단되는 비율 감소
4. **디버그 로그 보강** — 유휴 이탈 시 `systemIdleSeconds` 실제 값/임계값/분기 로그를 남겨 재발 분석 용이하게

## 3. 아키텍처

### 3.1 DB (DatabaseManager.swift)
```
updateTranscript = INSERT INTO video_ai_data
  (video_id, transcript, transcript_language, subtitle_source, subtitles_json, updated_at)
  VALUES (?,?,?,?,?, CURRENT_TIMESTAMP)
  ON CONFLICT(video_id) DO UPDATE SET
    transcript = excluded.transcript,
    transcript_language = excluded.transcript_language,
    subtitle_source = COALESCE(excluded.subtitle_source, subtitle_source),
    subtitles_json  = COALESCE(excluded.subtitles_json, subtitles_json),
    updated_at = CURRENT_TIMESTAMP;
```
- 기존 `UPDATE`에서 쿼리 교체만. 호출부(IdleSubtitleService/DownloadManager/SummarizationService)는 변경 불필요

### 3.2 `IdleSubtitleService.swift`
- 신규 상태: `lastStartNotificationDate`, `lastStopNotificationDate`, `notificationDebounceSeconds = 120`
- 시작 팝업(`startIfNeeded`): debounce 내 재시작이면 `logAndNotify(message:)` (시작 알림 없이 ActivityLog만)
- 중단 팝업(`cancelIfDownloading`): 동일
- `deactivationGraceSeconds: TimeInterval = 60`
- 유휴 해제/중단 시 디버그 로그에 `systemIdleSeconds()/임계/경과 초` 포함

## 4. 구현 단계 (T#)

| T# | 작업 | 상태 |
|----|------|------|
| T-360 | PLAN_v3.6 + TODO 등록 | done |
| T-361 | `updateTranscript` UPSERT (DatabaseManager) | pending |
| T-362 | 팝업 디바운스 + 유예 60초 + 디버그 로그 (IdleSubtitleService) | pending |
| T-363 | 빌드(debug macos) + idle_activity.log 재확인 + doc/session 업데이트 | pending |

## 5. 테스트 계획

- TC-1 Whisper 성공 → 같은 영상이 다음 사이클에서 다시 안 나오는지 (로그 "총 N개"가 줄어드는지)
- TC-2 유휴 해제 → 60초 이내 재유휴 시 중단 안 되는지
- TC-3 시작/중단 알림이 1회만 뜨는지(디바운스), ActivityLog는 누락 없는지
- TC-4 `hasSubtitles` UI 배지가 해당 영상에 표시되는지

## 6. 롤백

- `updateTranscript`는 SQL 문 하나만 영향 → 이전 `UPDATE`로 revert, 파괴적 마이그레이션 없음
- 팝업 debounce/그 유예 상수만 이전값 복원