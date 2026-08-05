# PLAN_v3.0_macos — v3.0 신규 기능 (macOS)

> 문서 우선 원칙: 코드 수정 전 계획 먼저. 본 문서는 v3.0 기능 기획·구현 로드맵이다.
> 1인 개인 프로젝트 기준 (AGENTS.local.md §0) — "내가 쓰기에 편리한가"가 최우선.

## 1. 개요

v2.9(리팩토링) 완료 후 첫 메이저 기능 버전. 사용자(제작자)가 선택한 4개 기능을 Phase로 나눠 순차 구현한다.

| Phase | 기능 | 핵심 가치 |
|-------|------|-----------|
| A | 자막·요약 전역 검색 | 보관함 수백 개 영상 중 내용 기반 검색 |
| B | 플레이어 고도화 | 재생 속도/A-B 반복/연속 재생 |
| C | 홈 화면 위젯 | 다운로드 상태 홈 화면 확인 |
| D | 브라우저 통합 | 브라우저에서 원클릭 전송 (scheme 확장) |

## 2. 결정 사항

- **D1 검색 인덱스**: 별도 FTS5 인덱스 대신 기존 `video_ai_data` 테이블에 `LIKE` 검색으로 1차 구현 (1인 사용, 데이터 규모 수천 건 내외 → 성능 문제 없음). 만족 안 되면 FTS5 마이그레이션 후속.
- **D2 검색 대상 필드**: transcript(자막), summary, subtitlesData, title, channelName. 결과는 기존 보관함 목록으로 표시 + 요약/자막 하이라이트 미리보기.
- **D3 플레이어 속도/A-B**: libmpv 속성 `speed` + `ab-loop-a/b` 명령 활용. 컨트롤바 확장.
- **D4 연속 재생**: PlayerReducer에 재생 목록(queue) State 추가. 이전/다음 버튼. 소스: 보관함 선택 항목·채널.
- **D5 위젯**: WidgetKit (macOS 14+). 다운로드 상태 공유는 **App Group** `group.com.tubekeep` UserDefaults에 별도 기록 (기존 `.standard` 마이그레이션은 2단계, 위젯부터 그룹 저장 병행).
- **D6 브라우저 통합**: 기존 `tubekeep://` scheme 확장 (URL/비디오 쿼리 수신 → 자동 다운로더 창 + 정보 조회). Safari/Chrome 확장 앱은 별도 검토(범위 큼, 후순위).

## 3. 아키텍처 (플랫폼: macOS, SwiftUI + TCA + libmpv)

### Phase A — 전역 검색
- `DatabaseManager.searchContent(query:)` — `video_ai_data` + `library` 대상 LIKE 검색, 매칭 스니펫 반환
- `LibraryReducer`: 검색 모드(`searchScope: .title / .content`) State, `filteredItems`에 반영
- 사이드바 검색창: 검색 범위 토글 + 결과 수 표시. 콘텐츠 검색 결과는 보관함 그리드/목록에 표시하고, 우클릭 → "요약/자막 보기"

### Phase B — 플레이어 고도화
- `MPVClient`: `setPlaybackRate(_:)`(speed), `setABLoop(a:b:)`/`clearABLoop()`(ab-loop-a/b), `nextChapter` 등 명령
- `PlayerReducer`: `playbackRate`, `aLoop`, `bLoop`, `queue: [PlayerItem]`, `queueIndex` State + 액션
- `PlayerView` 컨트롤바: 속도 버튼(0.75/1.0/1.25/1.5/2.0) + A/B 버튼 + 이전/다음(재생 목록) + 자막 스타일(크기/색) 패널

### Phase C — 위젯 (WidgetKit)
- SwiftPM에 `TubeKeepWidget` **executableTarget** 추가 (`.appExtension` product는 macOS 위젯에서 미지원 → 위젯 코드를 executable로 빌드 후 `.appex` 번들로 수동 조립)
- `build-macos.sh`: 위젯 빌드(`swift build --target TubeKeepWidget`) → `Contents/PlugIns/TubeKeepWidget.appex/Contents/MacOS/` 배치 + 위젯 Info.plist(`NSExtensionPointIdentifier: com.apple.widgetkit-extension`) + entitlement 서명
- **App Group** `group.com.tubekeep`: 앱·위젯 모두 `com.apple.security.application-groups` entitlement로 ad-hoc 서명 → 그룹 컨테이너 `~/Library/Group Containers/group.com.tubekeep/`
- 앱: 다운로드 상태 스냅샷(진행 중 제목/진행률/속도, 대기 수, 최근 완료)을 `UserDefaults(suiteName:)`에 기록 + 상태 변경 시 `WidgetCenter.reloadTimelines`
- 위젯: TimelineProvider가 그룹 UserDefaults 스냅샷을 읽어 1분 타임라인으로 표시
- App Group UserDefaults `group.com.tubekeep`에 다운로드 상태(진행 중 항목/진행률/대기 수/최근 완료) 기록 — `AppReducer`/`DownloadQueueReducer`가 상태 변경 시 저장
- 위젯: 큐 진행률 링 + 진행 중 목록 + 최근 완료

### Phase D — 브라우저 통합 (scheme 확장)
- `tubekeep://add?url=...` — URL 수신 시 다운로더 창 열고 자동 조회
- `tubekeep://open?id=...` — 보관함 ID로 플레이어/요약 열기
- AppDelegate `application(_:open:)` 핸들러 확장 (현재 scheme 처리와 통합)
- 브라우저 확장(Safari/Chrome)은 별도 PLAN 검토

## 4. 구현 단계 (T-번호)

| T-번호 | 작업 | 진행 상태 |
|--------|------|-----------|
| T-1000 | PLAN_v3.0 + TODO 등록 | 완료 |
| T-1001 | DatabaseManager.searchContent + 테스트 | 완료 — 기존 video_fts(FTS5)+searchFTS로 이미 구현 확인 |
| T-1002 | LibraryReducer 검색 모드 + 사이드바 검색 UI | 완료 — 기존 setSearchText→SearchService→searchResults로 이미 구현 |
| T-1003 | 콘텐츠 검색 결과 보강: 스니펫 하이라이트 + 클릭 시 해당 시간 재생 | 완료 — SnippetTextView + locateMatch + playSearchMatch |
| T-1010 | MPVClient 속도/A-B 반복 명령 | 완료 — speed + ab-loop-a/b/off |
| T-1011 | PlayerReducer 재생 속도·A-B·재생 목록 State | 완료 — queue/queueIndex, setQueue/playNext/playPrevious |
| T-1012 | PlayerView 컨트롤바 확장 | 완료 — 속도(0.75~2.0x)/A-B(3단계)/이전·다음, onChange→mpv 반영 |
| T-1013 | A-B 반복 UX 개선 + 재생 목록 패널 | 완료 — 시작점A/끝점B 2버튼 + 슬라이더 구간 오버레이 + showQueue 패널 + playAtQueue |
| T-1020 | WidgetKit 타깃 + App Group 상태 공유 | 완료 — executableTarget + 수동 appex 조립 + group.com.tubekeep entitlement |
| T-1021 | 위젯 뷰 (진행률/대기/최근 완료) | 완료 — DownloadStatus small/medium + 1분 타임라인 + reloadTimelines |
| T-1030 | tubekeep:// scheme 확장 (add/open) | D |

## 5. 테스트 계획

- 각 Phase: `./build_and_run.sh debug macos --no-launch` 성공 + `swift test` (기존 76개 그린 유지)
- A: 자막/요약 키워드 검색 → 해당 영상 + 스니펫 노출
- B: 속도 1.5x 재생, A→B 반복, 보관함 선택 여러 개 이전/다음
- C: 위젯 추가 → 다운로드 진행률 반영 (앱 그룹 공유 확인)
- D: `open "tubekeep://add?url=https://youtu.be/..."` → 다운로더 열림 + 자동 조회

## 6. 롤백 계획

- A: 검색 모드 State 제거/기존 필터링 복구 (git revert)
- B: MPVClient 신규 메서드 + PlayerReducer State 제거
- C: 위젯 타깃 제거 + build_and_run.sh 원복 + App Group 기록 제거
- D: scheme 핸들러 원복

## 7. 성능 예산

| 지표 | 목표 |
|------|------|
| 전역 검색 (1만 건 내역) | ≤ 200ms |
| 위젯 위젯 갱신 주기 | 1분 (timeline) |
| 플레이어 속도/A-B 반복 | 0.5~2.0x, 즉시 반영 |

## 8. 에러코드 목록 (error_message_ko.json)

- `E-MAC-DB-1001`: 콘텐츠 검색 실패 (검색어 처리 오류)
- `E-MAC-PLAY-1002`: 재생 속도/A-B 반복 적용 실패

## 9. 빌드/권한

- C(위젯) 구현 시 `entitlements`에 App Group 추가 필요 (macOS에서는 코드 서명 시 app sandbox 아님 — 기존 비샌드박스 유지)
- 새 권한(파일/네트워크) 없음
