# PLAN v4.4 — 오디오 다운로드 실패 수정 (macOS)

- 플랫폼: macOS
- 버전: v4.4
- 작성일: 2026-08-20
- 관련: bd/TODO T-1182

## 개요

영상 다운로드가 실패(재시도 3회 후 "알 수 없는 오류"). yt-dlp가 실제 미디어 대신 `.mhtml`(스토리보드) 파일만 저장.

## 결정 사항

- 원인: yt-dlp 포맷 목록의 **storyboard 포맷(sb0~sb3, ext=mhtml)** 이 `vcodec=none`이라 앱의 `parseFormats`에서 `isAudioOnly=true`로 분류됨.
- 동시에 실제 오디오 포맷(139/140/249/250/251, height=0)은 `guard height > 0`에서 제외되어 목록에 없음.
- 그 결과 오디오 다운로드 시 sb*(스토리보드)가 선택 → `-f sb3/sb3` → mhtml 저장 → `isValidMediaFile` 실패.
- 최신 yt-dlp(2026.08.19)로도 동일 재현 확인 (`[mhtml] Total fragments: 1`).

## 수정

1. `parseFormats`에서 storyboard(sb*, mhtml) 명시적 제외
2. height=0 순수 오디오 포맷을 별도 수집 → 목록에 포함
3. 정렬: 오디오는 품질(filesize) 높은 순으로 배열 앞, 비디오는 기존 height desc

## 구현 단계

- T-1182: YouTubeDLService.parseFormats 수정 (storyboard 제외 + 오디오 포함)
- T-1183: 재빌드 + 번들 교체 + 앱 검증

## 테스트 계획

- TC-001: 오디오 다운로드 → 실제 m4a/aac 파일 생성 + 성공 처리
- TC-002: 비디오 다운로드 → 기존 동작 회귀 없음 (mp4 생성)

## 롤백

- git revert 해당 커밋 + 재빌드