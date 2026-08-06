#!/bin/bash
# test-core.sh — TubeKeep 핵심 기능 자동화 테스트 + 수동 체크리스트 안내
#
# 자동화 범위: 환경 의존성 / 빌드 / 유닛 테스트 / 설정·리소스 무결성 /
#              앱 번들 포함 리소스 / 스모크 실행(로그·잔여 프로세스) / a11y-dump
# 자동화 불가 항목은 마지막에 docs/tests/manual-checklist.md로 안내한다.
#
# Usage:
#   ./scripts/test-core.sh              전체 실행 (기본)
#   ./scripts/test-core.sh --skip-smoke 앱 스모크 테스트 생략
#   ./scripts/test-core.sh --skip-build 빌드·번들 생략 (빠른 회귀)
#   ./scripts/test-core.sh --help       도움말
#
# Exit: 0 = 전부 통과, 1 = FAIL 항목 존재

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="TubeKeep"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0
FAILURES=()
SKIP_SMOKE=false
SKIP_BUILD=false

for arg in "$@"; do
  case $arg in
    --skip-smoke) SKIP_SMOKE=true ;;
    --skip-build) SKIP_BUILD=true ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \?//'
      exit 0 ;;
  esac
done

RESULT_DIR="docs/tests/results"
mkdir -p "$RESULT_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)
RESULT="$RESULT_DIR/auto-test-$STAMP.md"

log()  { echo -e "${CYAN}[test-core]${NC} $1"; }
pass() { PASS=$((PASS+1)); echo -e "  ${GREEN}✅ PASS${NC} $1"; }
fail() { FAIL=$((FAIL+1)); FAILURES+=("$1"); echo -e "  ${RED}❌ FAIL${NC} $1"; }
warn() { WARN=$((WARN+1)); echo -e "  ${YELLOW}⚠️  WARN${NC} $1"; }
section() { echo; echo -e "${CYAN}━━━ $1 ━━━${NC}"; }

# 리포트에 한 줄 기록
note() { echo "$1" >> "$RESULT"; }

{
  echo "# TubeKeep 자동화 테스트 결과"
  echo ""
  echo "- 실행: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- 버전: $(plutil -extract CFBundleShortVersionString raw -o - Info.plist 2>/dev/null || echo '?') (build $(plutil -extract CFBundleVersion raw -o - Info.plist 2>/dev/null || echo '?'))"
  echo ""
} >> "$RESULT"

# ──────────────────────────────────────────────
section "1. 환경 의존성 확인"
note "## 1. 환경 의존성"

if command -v swift >/dev/null 2>&1; then
  pass "swift: $(swift --version 2>&1 | head -1)"
else
  fail "swift 없음"
fi

if command -v python3 >/dev/null 2>&1; then
  pass "python3: $(python3 --version 2>&1)"
else
  warn "python3 없음 (yt-dlp 번들 시 필요)"
fi

if command -v brew >/dev/null 2>&1; then
  pass "brew 확인"
else
  warn "brew 없음"
fi

for BIN in yt-dlp ffmpeg ffprobe; do
  if command -v "$BIN" >/dev/null 2>&1; then
    pass "시스템 $BIN: $(command -v "$BIN")"
  else
    warn "시스템 $BIN 없음 (번들 리소스로 대체 확인)"
  fi
done

# ──────────────────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
section "2. 빌드 (swift build -c debug)"
note "## 2. 빌드"
log "빌드 시작..."
if swift build -c debug > /tmp/tubekeep-build.log 2>&1; then
  pass "빌드 성공"
else
  fail "빌드 실패"
  tail -20 /tmp/tubekeep-build.log
fi
fi

# ──────────────────────────────────────────────
section "3. 유닛 테스트 (swift test)"
note "## 3. 유닛 테스트"
log "테스트 시작..."
if swift test > /tmp/tubekeep-test.log 2>&1; then
  TOTAL=$(grep -oE "Executed [0-9]+ tests" /tmp/tubekeep-test.log | tail -1 | grep -oE "[0-9]+" || echo "?")
  pass "유닛 테스트 통과 (${TOTAL}개)"
else
  fail "유닛 테스트 실패"
  grep -E "failed|error:" /tmp/tubekeep-test.log | tail -20
fi

# ──────────────────────────────────────────────
section "4. 설정·리소스 무결성"
note "## 4. 설정·리소스 무결성"

if [ -f Info.plist ]; then
  SHORT=$(plutil -extract CFBundleShortVersionString raw -o - Info.plist 2>/dev/null)
  BUILD=$(plutil -extract CFBundleVersion raw -o - Info.plist 2>/dev/null)
  pass "Info.plist 버전 $SHORT (build $BUILD)"
else
  fail "Info.plist 없음"
fi

for JSON in error_message_ko.json docs/AI_MODELS.json; do
  if [ -f "$JSON" ]; then
    if python3 -m json.tool "$JSON" > /dev/null 2>&1; then
      pass "$JSON JSON 유효"
    else
      fail "$JSON JSON 파싱 실패"
    fi
  else
    warn "$JSON 없음"
  fi
done

if defaults read group.com.tubekeep > /dev/null 2>&1; then
  pass "그룹 도메인 group.com.tubekeep 접근 가능"
else
  warn "그룹 도메인 데이터 없음 (앱 미실행 시 정상)"
fi

STORAGE_DIR="$HOME/Documents/TubeKeep"
if [ -d "$STORAGE_DIR" ]; then
  pass "기본 저장 폴더 존재: $STORAGE_DIR"
else
  mkdir -p "$STORAGE_DIR"
  warn "기본 저장 폴더 신규 생성: $STORAGE_DIR"
fi

# ──────────────────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
section "5. 앱 번들 빌드 + 포함 리소스"
note "## 5. 앱 번들 + 리소스"
log "build-macos.sh debug 실행 (앱 번들 생성)..."
if scripts/build-macos.sh debug false > /tmp/tubekeep-bundle.log 2>&1; then
  pass "앱 번들 생성 성공: $APP_BUNDLE"
else
  fail "앱 번들 생성 실패"
  tail -20 /tmp/tubekeep-bundle.log
fi

if [ -d "$APP_BUNDLE" ]; then
  for BIN in yt-dlp ffmpeg ffprobe; do
    if [ -x "$APP_BUNDLE/Contents/Resources/$BIN" ]; then
      pass "번들 리소스 $BIN 포함"
    else
      fail "번들 리소스 $BIN 없음"
    fi
  done
  if [ -x "$APP_BUNDLE/Contents/Resources/whisper-cli" ]; then
    pass "번들 리소스 whisper-cli 포함"
  else
    warn "번들 whisper-cli 없음 (없어도 필수 아님)"
  fi
  if [ -f "$APP_BUNDLE/Contents/Frameworks/libmpv.2.dylib" ]; then
    pass "libmpv.2.dylib 내장"
  else
    warn "libmpv.2.dylib 미내장"
  fi
  if codesign -v "$APP_BUNDLE" 2>/dev/null; then
    pass "코드 서명 검증 (ad-hoc)"
  else
    warn "코드 서명 검증 실패"
  fi
fi
fi

# ──────────────────────────────────────────────
if [ "$SKIP_SMOKE" = false ] && [ -d "$APP_BUNDLE" ]; then
section "6. 스모크 테스트 (앱 실행)"
note "## 6. 스모크 테스트"
log "앱이 잠시 실행됩니다 (약 8초)..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

SMOKE_LOG=$(mktemp)
"$APP_BUNDLE/Contents/MacOS/$APP_NAME" > "$SMOKE_LOG" 2>&1 &
SMOKE_PID=$!
sleep 6

if kill -0 "$SMOKE_PID" 2>/dev/null; then
  pass "앱 실행 유지 (pid $SMOKE_PID)"
  note "- 앱 실행 유지: ✅"
else
  fail "앱이 실행 중 종료됨 (크래시 의심)"
  note "- 앱 실행 유지: ❌"
  tail -20 "$SMOKE_LOG"
fi

ERR_COUNT=$(grep -ciE "fatal|crash|uncaught|error:" "$SMOKE_LOG" || true)
if [ "${ERR_COUNT:-0}" -eq 0 ]; then
  pass "실행 로그에 Fatal/Crash/ERROR 패턴 없음"
  note "- 로그 에러 패턴: ✅ ($(wc -l < "$SMOKE_LOG" | tr -d ' ')줄 캡처)"
else
  warn "실행 로그에 ERROR 패턴 ${ERR_COUNT}건 (정상 경로일 수 있음)"
  grep -iE "fatal|crash|uncaught|error:" "$SMOKE_LOG" | head -5
  note "- 로그 에러 패턴: ⚠️ ${ERR_COUNT}건"
fi

kill "$SMOKE_PID" 2>/dev/null || true
wait "$SMOKE_PID" 2>/dev/null || true
sleep 1

LEFTOVER=$(pgrep -fl "yt-dlp|ffmpeg|ffprobe" 2>/dev/null | grep -v "$$" || true)
if [ -z "$LEFTOVER" ]; then
  pass "잔여 yt-dlp/ffmpeg 프로세스 없음"
  note "- 잔여 프로세스: ✅"
else
  fail "잔여 프로세스 발견: $LEFTOVER"
  note "- 잔여 프로세스: ❌ $LEFTOVER"
fi
rm -f "$SMOKE_LOG"
fi

# ──────────────────────────────────────────────
section "7. a11y-dump (텍스트 검증 덤프)"
note "## 7. a11y-dump"
if scripts/a11y-dump.sh > /tmp/tubekeep-a11y.log 2>&1; then
  pass "a11y-dump 3종 생성"
  note "- a11y-dump: ✅"
else
  warn "a11y-dump 생성 실패"
  tail -10 /tmp/tubekeep-a11y.log
  note "- a11y-dump: ⚠️"
fi

# ──────────────────────────────────────────────
section "결과 요약"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS   ${RED}FAIL${NC}: $FAIL   ${YELLOW}WARN${NC}: $WARN"
{
  echo ""
  echo "## 요약"
  echo "- PASS: $PASS"
  echo "- FAIL: $FAIL"
  echo "- WARN: $WARN"
  if [ "$FAIL" -gt 0 ]; then
    echo "- 실패 항목:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
  fi
} >> "$RESULT"

echo ""
log "리포트 저장: $RESULT"

# ──────────────────────────────────────────────
section "수동 테스트 항목 안내"
echo ""
echo -e "${YELLOW}자동화 테스트는 완료되었습니다.${NC}"
echo -e "아래 항목은 자동화할 수 없으므로 수동으로 확인해 주세요:"
echo ""
if [ -f "docs/tests/manual-checklist.md" ]; then
  cat "docs/tests/manual-checklist.md"
else
  echo "(manual-checklist.md 없음)"
fi

if [ "$FAIL" -gt 0 ]; then
  echo -e "\n${RED}[test-core] ${FAIL}개 FAIL 항목이 있습니다. 수동 테스트 전에 해결하세요.${NC}"
  exit 1
fi
echo -e "\n${GREEN}[test-core] 자동화 테스트 전체 통과 ✅ 수동 테스트를 진행하세요.${NC}"
exit 0
