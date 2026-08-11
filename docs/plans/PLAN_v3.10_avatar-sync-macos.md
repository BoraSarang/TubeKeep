# PLAN v3.10 — 채널 아바타 동기화 (macOS)

## 개요
채널 아바타가 화면별로 갱신 동기가 안 맞는 문제 수정.
- 보관함 헤더에서 정보 갱신 → 콘텐츠 아바타만 갱신되고 사이드바는 안 됨
- 채널 다운로더도 동일 문제 (갱신 시 이미지 캐시/통지 미발행)
- 한쪽에서 갱신하면 모든 화면에 자동 반영 (양방향)

## 결정 사항
- `CachedAvatarView`를 갱신 감지형으로: `url` 변경 + `channelInfoDidUpdateNotification` 구독 → 재로드
- 채널 다운로더 `refreshChannelInfo`에서 이미지 다운로드+캐시+통지 발행 추가
- 기존 `LibrarySidebarView.updateAvatarURLs()` 유지 (이중 안전망)

## 아키텍처
- 모든 아바타 표시는 `CachedAvatarView`(`Resources/Views`) 경유
  - 보관함 사이드바 (20px), 채널 콘텐츠 헤더 (60px), 채널 목록 Row (28px)
- 갱신 발행처: `ChannelHeaderView.refreshChannelInfo` (기존 ✅), `ChannelDownloaderView.refreshChannelInfo` (신규 추가)
- 통지: `Constants.channelInfoDidUpdateNotification`, userInfo `["channelId"]`

## 구현 단계
- T-1: `CachedImageViews.swift` — `CachedAvatarView`에 `.onChange(of: url)` + `.onReceive(channelInfoDidUpdateNotification)` 재로드
- T-2: `ChannelDownloaderView.swift` — `refreshChannelInfo` 성공 시 아바타 다운로드 → `cacheAvatar` → 통지 발행
- T-3: 빌드 검증 + 샘플 검증

## 테스트 계획
- TC-1: 보관함 헤더에서 정보 갱신 → 사이드바 아바타 즉시 갱신
- TC-2: 채널 다운로더에서 정보 갱신 → 사이드바/보관함 콘텐츠 갱신
- TC-3: 캐시 클리어 후에도 재다운로드 정상 (placeholder 폴백 유지)

## 롤백 계획
- `git revert` + `./build_and_run.sh debug macos`

## 성능 예산
- 아바타 다운로드는 URLSession 1회, 기존 리소스 재사용. 신규 문제 없음

## 에러코드
- 신규 없음 (기존 E-CACHE 계열 재사용)