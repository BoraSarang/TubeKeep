#!/bin/bash
# a11y-dump.sh — macOS 텍스트 전용 모델 검증 덤프 (AGENTS.md 7.6.1 macOS 적응)
# usage: ./scripts/a11y-dump.sh [VERSION]   (기본: v이 없으면 git tag/version 추출)
# output: docs/screenshots/macos/{VERSION}_{scope}.txt | .storage.json | .perf.json
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP="TubeKeep"
VERSION="${1:-v$(plutil -extract CFBundleShortVersionString raw -o - Info.plist 2>/dev/null || echo unknown)}"
OUT="docs/screenshots/macos"
mkdir -p "$OUT"

STAMP=$(date +%Y%m%d_%H%M%S)
NAME="${OUT}/${VERSION}_${STAMP}"

# 1) 앱/빌드 상태 스냅샷 (.a11y.txt)
{
  echo "===== TubeKeep 메타데이터 (${VERSION}) ====="
  echo "빌드 시각: $(date)"
  echo "CFBundleShortVersionString: $(plutil -extract CFBundleShortVersionString raw -o - Info.plist 2>/dev/null || echo '?')"
  echo "CFBundleVersion: $(plutil -extract CFBundleVersion raw -o - Info.plist 2>/dev/null || echo '?')"
  echo
  echo "===== 최근 커밋 (git log -5) ====="
  git log --oneline -5 2>/dev/null || echo "(git 없음)"
  echo
  echo "===== 저장된 앱 ====="
  ls -ld "$HOME/Applications/${APP}.app" 2>/dev/null || echo "(미설치)"
  ls -lh "$HOME/Applications/${APP}.app"*.dmg 2>/dev/null || true
  echo
  echo "===== yt-dlp / ffmpeg 번들 ====="
  ls -lh "$HOME/Applications/${APP}.app/Contents/Resources/yt-dlp" 2>/dev/null || echo "yt-dlp 찾지 못함"
} > "${NAME}.a11y.txt"

# 2) 스토리지/DB 스냅샷 (.storage.json)
{
  APP_SUPPORT="$HOME/Library/Application Support"
  DB=$(find "$APP_SUPPORT" "$HOME/Documents" -maxdepth 4 -name "*.sqlite*" 2>/dev/null | head -20)
  printf '{\n'
  printf '  "version": "%s",\n' "$VERSION"
  printf '  "sqlite_files": [\n'
  FIRST=1
  for d in $DB; do
    [ -z "$d" ] && continue
    size=$(stat -f%z "$d" 2>/dev/null || echo 0)
    if [ "$FIRST" -eq 1 ]; then FIRST=0; else printf ',\n'; fi
    printf '    {"path": "%s", "bytes": %s}' "$d" "$size"
  done
  printf '\n  ]\n}\n'
} > "${NAME}.storage.json"

# 3) 퍼프 스냅샷 (.perf.json)
{
  BIN_HUMAN=$(du -sh .build/debug "$HOME/Applications/${APP}.app" 2>/dev/null | head -5 || true)
  printf '{ "version": "%s", "artifact_sizes": %s }\n' \
    "$VERSION" "$(python3 - <<PY 2>/dev/null || echo 'null')
import json,subprocess
out=[]
for p in ['.build/debug','$HOME/Applications/${APP}.app']:
    try:
        r=subprocess.run(['du','-sk',p],capture_output=True,text=True)
        size=int(r.stdout.split()[0])*1024; out.append([p,size])
    except: pass
print(json.dumps(dict((a[0],a[1]) for a in out)))
PY"
} > "${NAME}.perf.json"

echo "[a11y] 생성 완료:"
ls -lh "${NAME}".a11y.txt "${NAME}".storage.json "${NAME}".perf.json