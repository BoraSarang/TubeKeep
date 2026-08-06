# PLAN v3.2 — 자주 쓰는 흐름 자동화 (macOS)

**버전**: v3.2.0 · **작성일**: 2026-08-06 · **상태**: 계획 수립

## 1. 개요

v3.1.1(버그 수정) 릴리즈 후 다음 버전. "받고 → 보고 → 정리"의 반복 작업을 자동화하는 기능 6종.
A 이어보기, B 유휴 AI 배치, C 채널 자동 다운로드 v2, D 중복 방지, E 재생목록 감시, F 큐 드래그 재정렬.

## 2. 결정 사항

| 항목 | 결정 |
|------|------|
| A 이어보기 | `LibraryItem.lastPlaybackPosition`(Double) + `lastPlayedAt`(Date) 추가. 재생 중 5초 주기 저장(정지/닫기 시 즉시). 그리드/목록에 이어보기 배지(시청 중단 위치), 재생 시 해당 위치에서 재개 |
| B 유휴 AI 배치 | T-1044 자막 다운로드 확장 — 자막 저장 후 선택적으로 요약+태깅(필수) / 팟캐스트(선택) 자동 생성. 설정에 "유휴 시 자동 생성" 옵션(요약/태깅/팟캐스트) |
| C 채널 자동 다운로드 v2 | `ChannelAutoDownloadSettings`(채널ID → 해상도/MP3/자막/하루 최대 개수) 저장. 기본값은 settings.defaultResolution. 신규 영상 enqueue 시 적용 |
| D 중복 방지 | 정보 조회(또는 enqueue) 시 보관함/히스토리에 같은 videoId 존재 → "이미 받음" 표시 + 다운로드 시 확인/스킵 |
| E 재생목록 감시 | 구독 재생목록 추가 → 채널 업데이트 확인 주기와 함께 신규 영상 감시 → 자동 다운로드 |
| F 큐 드래그 재정렬 | DownloadQueueView에서 대기 중 항목 드래그로 순서 변경 (배열 재정렬 + UserDefaults 영속) |

## 3. 아키텍처

```
A 이어보기:  PlayerReducer → 5초마다 .updatePlaybackPosition(id, position)
             → LibraryCacheService.updatePlaybackPosition(id) → SwiftData 저장
             → MainView 그리드/목록 배지 + 재생 시 PlayerItem.initialSeekTime에 position 전달
B 유휴 배치: IdleSubtitleService 자막 저장 후
             → SummarizationService.summarizeVideo(id) [CACHE 히트 시 생략]
             → TaggingService.tagVideo(id) + PodcastService.generatePodcast(id) [설정 시]
C 채널 프리셋: ChannelDownloadCache에 `channelAutoDownloadSettings: [String: ChannelAutoSettings]`
             → ChannelUpdateService.enqueueAutoDownload 시 해상도/옵션 적용
D 중복 방지: DownloadQueueReducer.addItems / HomeReducer.infoResponse에서
             → LibraryCacheService.findItem(id) + DatabaseManager.hasHistory(id) 체크
E 재생목록 감시: ChannelUpdateService와 동일 파이프라인, 재생목록 ID를 채널처럼 취급
             (yt-dlp --flat-playlist로 신규만 감지) → autoDownload 옵션 시 enqueue
F 큐 재정렬: DownloadQueueState.queue 배열 순서 변경 액션 + UserDefaults("downloadQueue") 저장
```

## 4. 구현 단계 (T-번호)

| T-번호 | 작업 | 진행 상태 |
|--------|------|-----------|
| T-1070 | PLAN_v3.2 + TODO 등록 | ✅ 계획 수립 |
| T-1071 | A 이어보기 — 모델/저장/배지/재개 | ✅ 구현 (빌드+테스트 76/76) |
| T-1072 | B 유휴 AI 배치 — 자동 요약/태깅/팟캐스트 | ⬜ |
| T-1073 | C 채널 자동 다운로드 v2 — 채널별 프리셋 | ⬜ |
| T-1074 | D 중복 다운로드 방지 | ⬜ |
| T-1075 | E 재생목록 감시 | ⬜ |
| T-1076 | F 큐 드래그 재정렬 | ⬜ |

## 5. State/Action 설계 (TCA)

### T-1071 이어보기
- `PlayerReducer.State`: `playbackSaveTask`(기존 없음) → 5초 주기 Task 추가
- `PlayerReducer.Action`: `.updatePlaybackPosition(Double)`, `.playbackPositionSaved`
- `LibraryReducer.Action`: `.resumeFromPosition(String)` → `openFile`에 initialSeekTime 전달
- `LibraryItem`: `lastPlaybackPosition: Double?`, `lastPlayedAt: Date?`

### T-1072 유휴 AI 배치
- `IdleSubtitleService`: 자막 저장 후 `shouldAutoSummarize`/`shouldAutoPodcast` 설정 확인 → 각 서비스 호출
- `Settings`: `idleAutoSummary: Bool`, `idleAutoPodcast: Bool` (기본 true/false)
- `SettingsNotificationsTab`: "유휴 시 자동 생성" 체크박스 2개

### T-1073 채널 프리셋
- `ChannelModels`: `ChannelAutoSettings: Codable` (resolution, mp3, subtitles, dailyLimit)
- `ChannelDownloadCache`: `channelAutoDownloadSettings` 키, CRUD
- `ChannelContentView`: 프리셋 편집 UI (자동 다운로드 GroupBox 내 확장)

### T-1074 중복 방지
- `HomeReducer`: infoResponse 시 `LibraryCacheService.findItem` + `DatabaseManager.loadDownloadHistory` 확인 → `isDuplicate` State → UI 표시
- `DownloadQueueReducer.addItems`: 중복 제외/확인 옵션

### T-1075 재생목록 감시
- `ChannelModels`: `SubscribedPlaylist` (id/title) + UserDefaults 저장
- `ChannelUpdateService`: 재생목록도 감시 대상에 포함 (playlist ID로 `--flat-playlist`)
- `ChannelContentView` 또는 별도 뷰: 재생목록 구독 UI

### T-1076 큐 재정렬
- `DownloadQueueState`: queue 배열 순서 (이미 배열) → `moveQueueItem(from:to:)` 액션
- `DownloadQueueView`: `.onMove` + 드래그 핸들 → 순서 저장

## 6. 에러코드

| 코드 | 메시지 |
|------|--------|
| E-MAC-PLAY-1001 | 이어보기 위치 저장 실패 |
| E-MAC-SUB-1002 | 유휴 AI 배치 실패 |
| E-MAC-CH-1001 | 채널 프리셋 저장 실패 |

## 7. 테스트 계획 (TC-번호)

- A: 영상 재생 1분 → 닫기 → 재생 시 해당 위치 재개 + 배지 확인
- B: 유휴 5분 → 자막 + 요약 생성 확인, 캐시 히트 시 요약 재사용
- C: 채널별 해상도/MP3 지정 → 신규 영상 해당 옵션으로 다운로드
- D: 이미 있는 영상 URL 조회 → "이미 받음" 표시 + 스킵
- E: 재생목록 구독 → 신규 영상 자동 다운로드
- F: 대기 항목 드래그 → 순서 변경 + 재시작 후 유지
- `swift test` 76/76 유지 + `./build_and_run.sh debug macos` ✅

## 8. 롤백 계획

- A: lastPlaybackPosition 필드 제거, 저장 Task 취소
- B: 설정 기본값 false, IdleSubtitleService 자동 생성 분기 제거
- C: 채널 프리셋 UserDefaults 키 삭제
- D: 중복 체크 로직 제거
- E: 재생목록 구독 키 삭제
- F: moveQueueItem 액션 제거

## 9. 성능/비용

- A: 5초 주기 SwiftData 저장 — 부하 미미 (이어보기 저장 1건/5초)
- B: 유휴 AI 배치는 API 비용 발생 — 요약은 CACHE 히트 활용, 팟캐스트는 기본 false로 비용 최소화
- C/E: 기존 채널 업데이트 주기(30분) 재사용 — 추가 네트워크 비용 없음
- D: 조회 시 DB 조회 2건 — 미미
