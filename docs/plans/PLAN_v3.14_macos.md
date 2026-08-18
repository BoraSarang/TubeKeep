# PLAN v3.14 — macOS TCC "앱 관리" 팝업 근본 해결 (메인 앱 샌드박스 전환)

## 개요
- TubeKeep 메인 앱이 **비-샌드박스** 상태로 App Group 컨테이너(`~/Library/Group Containers/`)에 접근
- macOS Sequoia+가 이를 "다른 앱의 데이터 접근"(AppData / 앱 관리)으로 간주해 **매 실행마다 팝업** 반복
- TCC "허용"을 눌러도 재확인을 막지 못함 (auth_value=5 유지)
- **해결: 메인 앱을 샌드박스로 전환** → 자체 App Group 접근은 팝업 없음

## 선행 작업 (완료)
- 번들 ID 통일: `com.borasarang.tubekeeper(.widget)` → `com.borasarang.tubekeep(.widget)`
- App Group: `group.com.tubekeep` → `6GPJQ7BQC9.com.tubekeep` (Team ID 접두사)
- 데이터 마이그레이션: UserDefaults / Group Container 이동, tccutil reset

## 결정 사항
1. 메인 앱 샌드박스 전환 (entitlements 추가)
2. 북마크에 `.withSecurityScope` 추가 (user-selected 폴더 지속 접근)
3. Podcast 경로를 저장 폴더 기준으로 통일 (`~/Documents/TubeKeep/Podcasts` 하드코딩 제거)
4. 데이터 마이그레이션: UserDefaults + Application Support → 새 앱 컨테이너

## 변경 범위
| 파일 | 변경 |
|------|------|
| `Entitlements/TubeKeep.entitlements` | `app-sandbox` + `network.client` + `files.user-selected.read-write` 추가 |
| `Sources/TubeKeep/Helpers/BookmarkManager.swift` | 북마크 옵션에 `.withSecurityScope` |
| `Sources/TubeKeep/Services/PodcastService.swift` | Podcast 경로 → storageDirectory 기준 (3곳) |
| `Sources/TubeKeep/Services/LibraryCacheService.swift` | Podcast 경로 → storageDirectory 기준 (1곳) |

## 데이터 마이그레이션
- `~/Library/Preferences/com.borasarang.tubekeep.plist` → `~/Library/Containers/com.borasarang.tubekeep/Data/Library/Preferences/`
- `~/Library/Application Support/com.borasarang.tubekeep/` → `~/Library/Containers/com.borasarang.tubekeep/Data/Library/Application Support/`
- Group Container 유지 / Podcast 폴더는 storageDirectory와 동일 위치
- **사용자 조작**: 앱 첫 실행 후 저장 폴더 재선택 (security scope 북마크 재생성)

## 구현 단계
- T-1138: entitlements 수정
- T-1139: BookmarkManager `.withSecurityScope`
- T-1140: Podcast/LibraryCache 경로 통일
- T-1141: 재빌드 + 데이터 마이그레이션
- T-1142: 검증 (팝업 0회, 다운로드/재생/위젯) + 문서 + 커밋

## 검증 계획
- TC-001: 앱 재시작 3회 — AppData 팝업 재표시 0회
- TC-002: 다운로드 정상 (저장 폴더 북마크 접근)
- TC-003: MPV 재생 정상 (샌드박스 dylib 로드)
- TC-004: 위젯 스냅샷 공유 정상 (App Group)
- TC-005: 설정/보관함 데이터 유지 (마이그레이션)

## 롤백
- `git revert` + 이전 빌드(`/Users/lee/Applications/TubeKeep.app`) 재설치
- 샌드박스 entitlement 제거 시 비-샌드박스로 복귀 (TCC 팝업 재발생은 알려진 한계)

## 리스크
- 샌드박스 전환으로 기능 회귀 위험 (MPV dylib, yt-dlp/ffmpeg 실행, 파일 접근)
- 문제 발생 시 추가 entitlement 검토: `disable-library-validation`, `allow-unsigned-executable-memory`
- 저장 폴더 재선택 1회 필요

## 추가 작업 (2026-08-16): yt-dlp 샌드박스 403 + 북마크 저장 실패
### 배경
- 샌드박스에서 yt-dlp 실행은 해결 (python-build-standalone 3.13 + 번들 yt-dlp-lib + launcher)했으나:
  1. YouTube 다운로드가 간헐 `HTTP 403` — 2026 yt-dlp가 JS 런타임(PO Token/서명) 요구. `deno` 번들로 해결
  2. 저장 폴더 썸네일 쓰기 `Operation not permitted` — 재선택 직후 파워박스 일시 접근만 유효, security-scoped 북마크가 UserDefaults에 저장 안 됨

### 변경
| 파일 | 변경 |
|------|------|
| `scripts/build-macos.sh` | deno 번들 섹션 추가 (Homebrew deno + `@loader_path/deno-libs/` 의존성 + 재서명), launcher에 `--js-runtimes deno:...` + `cd $TMPDIR` |
| `Sources/TubeKeep/Helpers/Constants.swift` | `youtubeExtractorArgs` → `[String]` 배열 (독립 `--extractor-args` 2개: `lang=ko` + `player_client=default,android_vr`) |
| `Sources/TubeKeep/Services/DownloadManager.swift` | extractor-args 배열 spread + ensureAccess 실패 로그 |
| `Sources/TubeKeep/Services/YouTubeDLService.swift` | extractor-args 배열 spread |
| `Sources/TubeKeep/Services/ChannelFetchService.swift` | extractor-args 배열 spread (4곳) |
| `Sources/TubeKeep/Helpers/BookmarkManager.swift` | `.minimalBookmark` 제거(`.withSecurityScope`만) + 저장/복원/접근 로그 |
| `Sources/TubeKeep/App/AppDelegate.swift` | 시작 시 ensureAccess 결과 로그 |
| `error_message_ko.json` | `E-MAC-STOR-1001` 추가 |

### 검증
- TC-006: 다운로드 3회 연속 성공 (deno + player_client=default,android_vr, 샌드박스 재현에서 확인)
- TC-007: 저장 폴더 재선택 → 북마크 저장 로그 + 재시작 후에도 접근 유지

## 추가 작업 (2026-08-16): 다운로드 완료 오인 + webm(video-only) 미병합 + 부분 파일 난립
### 배경
- 포맷 선택이 VP9 webm video-only(`f278`)를 고름 → `--merge-output-format mp4`가 호환 불가로 미병합 → 오디오 없는 webm만 생성
- 완료 판정(DownloadManager:232)이 `status==0 || 파일 존재`면 완료 처리 — **.fXXX 스트림 파일도 완료로 인정**, 접근 실패(F6D34C32)도 completed 기록
- 저장 폴더 접근 실패/앱 재시작으로 audio 스트림 중단 → `.part`/`.webp`/`.fXXX` 잔류 (폴더 개판)
- 소름/BTS mp4는 비정상 (video=png, opus+png) — 병합/리먹스 문제 잔재
### 변경
| 파일 | 변경 |
|------|------|
| `YouTubeDLService.swift` | `parseFormats`: 같은 해상도 선택 시 **mp4(h264/AV1) > webm(VP9)** 우선 |
| `DownloadManager.swift` | `isValidMediaFile`: `.fXXX` 스트림 파일 제외; 완료 판정 **actualPath 필수 + video-only 아님**; 실패/중단 시 `.part/.fXXX/.webp` 잔류물 정리; `buildDownloadArgs`: webm 선택 시 mp4 계열 포맷으로 대체 |
### 검증
- TC-008: 한그루브/소름/극한직업 재다운로드 → 최종 `mp4`(h264+aac) + 소리 정상 + 완료 표시 정확 (video-only 완료 오인 0)
- TC-009: 실패 2건(117ED876, F9286EAA) 재시도 성공