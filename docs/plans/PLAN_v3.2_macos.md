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

### T-1072 유휴 AI 배치 ✅
- `IdleSubtitleService`: 자막 저장 후 `Settings.idleAutoSummary`/`idleAutoPodcast` 확인 → `runAutoAI(for:)`에서 요약→태깅→팟캐스트 순차 실행 (완료 후 checkIdle 재개)
- 요약: `SummarizationService.summarizeVideo` (DB 캐시 히트 `provider == "cached"`면 저장 생략), 요약+챕터 저장, `TaggingService.classify`로 태그 저장
- 팟캐스트: `PodcastService.generatePodcast` (transcript 없으면 스킵)
- `Settings`: `idleAutoSummary: Bool = true`, `idleAutoPodcast: Bool = false`
- `SettingsNotificationsTab`: 유휴 자막 켜짐 시 "요약·태그 자동 생성"/"팟캐스트 자동 생성" 토글 2개 표시
- 취소: `cancelIfDownloading`이 `downloadTask.cancel()`로 AI 배치도 중단, 각 단계에서 `Task.isCancelled` 가드

### T-1073 채널 프리셋 ✅
- `ChannelModels`: `ChannelAutoSettings: Codable` (enabled, resolution, includeSubtitles, audioOnly, dailyLimit=0 무제한)
- `ChannelDownloadCache`: `channelAutoSettings` 키 CRUD(`loadAutoSettings`/`saveAutoSettings`, 구버전 `channelAutoDownload` bool fallback) + `channelDailyDownloadCount` 일일 카운트(날짜 키)
- `ChannelContentView`: 자동 다운로드 GroupBox 내 프리셋 UI — 채널 전환 시 loadPreset, 해상도/자막/MP3/토글 변경 시 savePreset, 자동 다운로드 켜짐 시 "하루 최대 다운로드 수" Picker(무제한/1~20)
- `ChannelUpdateService.enqueueAutoDownload`: 채널별 프리셋 적용(해상도/자막/MP3) + 일일 한도 초과 시 skip·잔여분만 enqueue·개수 증가 기록

### T-1074 중복 방지 ✅
- `HomeReducer`: `isDuplicate` State + `setDuplicate(Bool)` 액션. infoResponse 시 `.run` effect에서 `LibraryCacheService.findItem`(MainActor) + `DatabaseManager.loadDownloadHistory`(status == "completed") 확인 (플레이리스트는 제외)
- `HomeView`: 제목 아래 "이미 받은 영상입니다" 주황 배지
- `DownloadQueueReducer.addItems`: 완료 이력(`status == "completed"`) 영상도 중복 스킵 + "중복된 항목이 제외되었습니다" 토스트

### T-1075 재생목록 감시 ✅
- `ChannelModels`: `SubscribedPlaylist` (id/title/url) + UserDefaults `subscribedPlaylists` CRUD, `playlistID(from:)` URL 파싱, `storageKey(for:)` = `playlist:<id>`
- `ChannelFetchService.fetchAllVideos`: `isPlaylist` 옵션 → `https://www.youtube.com/playlist?list=<id>` fetch
- `ChannelUpdateService`: 채널 루프 후 재생목록 루프 — 1시간 주기 fetch → newVideos 저장(`playlist:` 키) → 자동 다운로드(`enqueueAutoDownload`에 `presetKey` 파라미터, 일일 한도도 `playlist:` 키로 집계)
- `ChannelListView`: 사이드바 하단 "재생목록" 섹션 — NSAlert URL 추가/삭제/자동 다운로드 토글/신규 배지

### T-1076 큐 재정렬 ✅
- `DownloadQueueReducer`: `setItems([DownloadItem])` 액션 — 순서 교체 후 saveQueue(영속)
- `DownloadQueueView`: ScrollView+LazyVStack → `List` 전환, `ForEach(store.items.reversed())` + `.onMove` — 표시 순서에서 move → reversed 복원 → `setItems` 반영

### T-1077 핵심 기능 자동화 테스트 ✅
- `scripts/test-core.sh`: 환경 의존성(swift/python3/yt-dlp/ffmpeg/ffprobe) → `swift build -c debug` → `swift test`(76개) → 설정·리소스 무결성(Info.plist 버전, error_message_ko.json·AI_MODELS.json JSON, 그룹 도메인, 저장 폴더) → `build-macos.sh` 번들 + 포함 리소스(yt-dlp/ffmpeg/ffprobe/whisper-cli/libmpv + codesign) → 스모크 테스트(앱 실행 alive → Fatal/ERROR 로그 검사 → 종료 → 잔여 yt-dlp/ffmpeg 없음) → `a11y-dump.sh` 3종
- 리포트: `docs/tests/results/auto-test-YYYYMMDD_HHMMSS.md` (PASS/FAIL/WARN + 실패 항목)
- 마지막에 `docs/tests/manual-checklist.md`(수동 테스트 체크리스트) 출력 — 자동화 불가 항목(TC-DL/PL/AI/CH/IDLE/SET) 안내
- 옵션: `--skip-smoke`(앱 실행 생략), `--skip-build`(빌드·번들 생략), `--help`

### T-1078 디버그 로그창 고도화 ✅
- AGENTS 19장 DebugPanel 표준(macOS: NSWindow .floating+100, Cmd+Shift+D) 준수 — 기존 유지
- `DebugLogManager`: `selectedLevels`(Set<DebugLogLevel>) + `searchText` 필터 상태, `levelCounts`(레벨별 카운트), `filteredLogs`(레벨+검색 조건부 computed), `toggleLevel(_:)`, `copyAll()`은 필터된 로그 기준으로 복사
- `DebugLogView`: 상단 필터 바 — 검색 필드(카테고리/메시지/meta, 대소문자 무시, 클리어 버튼) + 레벨 픽커(전체 + ERROR/WARN/API→/API←/PERF/CACHE/SYSTEM/ACTION/INFO 토글, 레벨 색상 테두리·카운트 배지) / 하단 상태 바 — "표시/전체" 카운트 + "필터링 중" 배지
- 로그 목록/자동 스크롤/선택(shift 다중·cmd 다중)이 `filteredLogs` 기준으로 동작
- PERF/CACHE 레벨 필터로 성능·캐시 히트 로그만 조회 가능 (AGENTS 7.5·8.13 로그 형식 연동)

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
- **자동화**: `./scripts/test-core.sh` — 환경/빌드/유닛 테스트/리소스/번들/스모크/a11y-dump 자동 수행 후 수동 체크리스트 안내
- **수동**: `docs/tests/manual-checklist.md` — TC-DL-01~06(다운로드/중복/큐 정렬), TC-PL-01~05(재생/이어보기/클립/단축키), TC-AI-01~05(AI/유휴 배치), TC-CH-01~04(채널/재생목록), TC-IDLE/SET-01~05(유휴/설정/마이그레이션)

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
