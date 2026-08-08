# PLAN v3.5 — 휴지통(soft delete) + 사이드바 채널 전체 삭제 + 용어 정리

> 플랫폼: macOS (TubeKeep 네이티브) · 작성일: 2026-08-08
> 이전 버전: v3.4 유휴 자막 개선

## 1. 개요

현재 삭제는 전부 즉시 물리 삭제(복원 불가)다. 실수 삭제 방지를 위해 **앱 내장 휴지통**을 도입하고,
왼쪽 사이드바 채널에 "채널 영상 모두 삭제"를 추가하며, "라이브러리" 용어를 "보관함"으로 통일한다.

## 2. 결정 사항

1. **휴지통 모델: 앱 내장 휴지통**
   - 삭제 = 원본 미디어 파일을 `{storageDir}/.Trash/<videoId>/` 로 이동 + `LibraryItem.trashedAt` 기록
   - AI 파생 DB(transcript/summary 등)·클립·썸네일은 **유지** → 복원 시 그대로 복구됨
   - 복원 = 파일을 원본 채널 폴더로 되돌림 + `trashedAt` nil
   - 영구 삭제 = 기존 `purgeAssociatedData`(AI DB + QnA + FTS + 클립 확인) + 물리 삭제
   - 시작 시 30일 경과 휴지통 항목 자동 정리
2. **채널 전체 삭제: 휴지통 이동 방식**
   - 사이드바 채널 우클릭: "채널 영상 모두 삭제" = 해당 채널 항목 전부 휴지통 이동 + 해당 채널 `download_history` 정리
   - 채널 다운로더의 기존 "채널 삭제"는 **영구 삭제 유지** (명시적 행동)
3. 디스크 사용량 계산은 휴지통 폴더(기본 storage 내 `.Trash`) 제외
4. 삭제로 인해 FTS 색인 제거는 영구 삭제 시에만

## 3. 아키텍처

### 3.1 데이터 모델
- `LibraryItem`에 `trashedAt: Date?` 추가 (nil=보관함, 값 있음=휴지통)
- `LibraryCacheService` 보관함 로드에서 `trashedAt == nil`만 반환 / 휴지통 목록은 `trashedAt != nil`

### 3.2 삭제 서비스 (`LibraryCacheService`)
```
trashDirectory          = {storageDir}/.Trash
trashTitle(_ id:)        — 파일 {storageDir}/.Trash/{videoId}/ 로 이동 + LibraryItem.trashedAt = now
trashItems(ids:)          — 일괄 이동
restoreItem(id:)          — .Trash/{videoId}/파일 → 원본 채널 폴더 복원 + trashedAt = nil
deletePermanently(id:)    — 핵심 삭제(기존 removeItem 로직 재사용, 단 하드 삭제)
emptyTrash()              — 휴지통 전체 영구 삭제
autoPurgeTrash(olderThan:) — 시작 시 30일 정리
```
- 파일 원본 위치 복원: 파일명 템플릿 `{index} - {title}.{id}` 마지막 `.{id}` 던은 videoId → 채널 폴더 = `sanitizeFolderName(channelName)`(Constants) → `{channelStorageDirectory}/{channelName}/{tip}`. 이동 직전 `.Trash/{videoId}/original_path.json` sidecar 기록 → 복원시 정확한 원 위치 사용(권장)

### 3.3 리듀서 (`LibraryReducer`)
- 액션: `trashItems([String])`, `restoreItem(String)`, `restoreItems([String])`, `deletePermanently(String)`, `emptyTrash`, `toggleTrashView`, `trashCountUpdated(Int)`
- State: `showTrash: Bool`, `trashIds: [String]`
- 보관함 로드 시 `loadFromDisk`에서 trashedAt 필터 + 휴지통 카운트 계산

### 3.4 UI
- `MainView`에 섹션: "보관함"/"휴지통" 전환 (사이드바 하단)
- `LibrarySidebarView.channelRow` contextMenu에 "채널 영상 모두 삭제" 추가 (성명 후 삭제, 휴지통 이동)
- 보관함 목록/그리드 메뉴: "라이브러리에서 삭제" → **"휴지통으로 이동"**
- `SelectionBar` 선택 삭제 → 휴지통 이동
- 휴지통 뷰: 항목 복원 / 영구 삭제 / 전체 비우기 / 남은 기간 표시

### 3.5 download_history 정합성
- 개별/일괄 휴지통 이동 시: `deleteDownloadHistory(videoId:)` 는 제거하지 않음(이력 보존)
- 채널 전체 휴지통 이동: `deleteDownloadHistory(channel:)` 호출
- 영구 삭제 시: `deleteDownloadHistory(id:)` 호출
- 팟캐스트: 영구 삭제 시 `deletePodcast(videoId:)`

## 4. 구현 단계 (T 번호)

| T# | 작업 | 상태 |
|----|------|------|
| T-1 | `LibraryItem.trashedAt` 추가 + 마이그레이션(경량) | |
| T-2 | `LibraryCacheService` 휴지통 서비스(이동/복원/영구삭제/비움/30일 자동정리) | |
| T-3 | `LibraryReducer` 액션/State/로드 필터 | |
| T-4 | 사이드바 채널 "채널 영상 모두 삭제" + download_history 정리 | |
| T-5 | 보관함 메뉴 명칭 "휴지통으로 이동" + SelectionBar 전환 | |
| T-6 | 휴지통 뷰(목록/복원/영구삭제/비우기) + 사이드바 진입 | |
| T-7 | 자동 정리(AppDelegate 시작 시) | |
| T-8 | 빌드(debug macos) + 수동 검증 + doc/session 업데이트 | |

## 5. 테스트 계획

- TC-1 단일 → 휴지통 이동 후 보관함 숨김, .Trash 존재 확인
- TC-2 복원 → 원 채널 폴더 복귀 + 보관함 재표시 (transcript 유지 확인)
- TC-3 영구 삭제 → 파일/파생 DB/클립 삭제 확인
- TC-4 채널 영상 모두 휴지통 이동 → 전 항목 + download_history 비움 확인
- TC-5 휴지통 전체 비우기
- TC-6 앱 재실행 시 30일 자동정리 로그 확인
- TC-7 디스크 사용량에 휴지통 제외 확인

## 6. 롤백
- SwiftData 마이그레이션 충돌 시: trashedAt 필드 추가 롤백(신규 app 빌드에서 데이터 재생성)
- 휴지 폴더 정리 시 파일 유실 대비: 복원 대상 파일 없으면 `E-LIB-TRASH` 에러 표시

## 7. 에러코드 (error_message_ko.json 추가)
| 코드 | 메시지 |
|------|--------|
| E-MAC-LIB-0111 | "휴지통 파일 이동에 실패했습니다. 권한을 확인해 주세요." |
| E-MAC-LIB-0112 | "휴지통에서 복원에 실패했습니다. 파일을 찾을 수 없습니다." |