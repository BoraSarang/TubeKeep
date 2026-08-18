# PLAN v4.3 — okstart 흔적 완전 제거 + git 이력 재작성 (macOS, T-1179~T-1181)

## 개요
- 프로젝트 전체에서 **`okstart` 브랜드 흔적을 완전 삭제** (파일 내용 + git 이력 + 원격 저장소)
- 치환 규칙: `okstart` → `borasarang`, `OkStart` → `BoRaSaRang` (AGENTS.md `com.borasarang.{AppName}` 컨벤션과 통일)
- 부수 작업: 이력 속 `build/` 폴더 제거 (GitHub Push Protection AWS 키 스캔 차단 해소)

## 결정 사항
1. okstart → borasarang 통일 (사용자 승인)
2. git 이력 전체 재작성 + 원격 force push (사용자 승인)
3. 원격 저장소 삭제 후 재생성 (tag push 규칙 위반 → 근본 해소)
4. 이력에서 `build/` 폴더 제거 — yt-dlp `shahid.py` 내부 예제 AWS 키가 GitHub Push Protection에 탐지됨

## 구현 단계 (완료)
- T-1179: 미커밋 작업(v4.0~v4.2 전체) 정리 커밋 — `0b4b6c4` → 필터 후 재작성
- T-1180: `git filter-repo --replace-text 'okstart==>borasarang'` 1차 (소문자만 치환 — 대문자 OkStart 누락 발견)
- T-1180: 2차 `--replace-text 'OkStart==>BoRaSaRang'` — AboutView 저작권/AGENTS.md 제작자 치환
- T-1181: 3차 `--invert-paths --path build/` — Push Protection 차단 해소 + main/태그 14개 force push

## 검증 결과
- `git log -S okstart -i` → **0건** / 커밋 메시지 grep → **0건**
- `rg -i okstart` (작업 트리, Build 제외) → **0건**
- 모든 태그(v1.0.0~v3.11.0) 커밋 → **0건**
- GitHub 코드 검색 API `q=okstart repo:BoraSarang/TubeKeep` → **0건**
- 원격: main + 태그 14개 push 완료, 이력 122 커밋
- 원본 이력 백업: `/var/folders/.../opencode/tubekeep-orig-backup.bundle` (52MB)

## 롤백 계획
- 원본 bundle에서 `git fetch` 후 원복 가능 (okstart 포함 원본 상태)
- 새 저장소는 `gh repo create --public`으로 재생성됨 — 원본 저장소는 삭제됨
