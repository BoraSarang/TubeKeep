#!/bin/bash
# env-expiry-check.sh — 시크릿 만료 체크 (AGENTS.md 8.12 macOS 적용)
# usage: ./scripts/env-expiry-check.sh [--json]
# 동작: .env/.env.example 및 *.example 에서 `# expires: YYYY-MM-DD` 파싱
#   - 만료 30일 전  → WARN  (bd create --label secret 권장)
#   - 만료 지남     → ERROR (빌드 실패 신호)
#   - 관리 대상 없음 → OK
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

JSON="${1:-}"
TODAY=$(date +%s)
WARN_DAYS=30

FILES=$(find . -maxdepth 3 \( -name ".env" -o -name ".env.example" -o -name "*.example" \) -not -path "*/.*" 2>/dev/null || true)

if [ -z "$FILES" ]; then
  echo "[env-expiry] ✅ 관리 대상 시크릿 없음 (OK)"
  exit 0
fi

declare -a FOUND=()
for f in $FILES; do
  while IFS= read -r line; do
    case "$line" in
      *#\ expires:\ *)
        expiry=${line#*# expires: }
        expiry=${expiry%% *}
        if [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
          exp_ts=$(date -j -f "%Y-%m-%d" "$expiry" "+%s" 2>/dev/null || true)
          if [ -n "$exp_ts" ]; then
            FOUND+=("$f|$expiry|$exp_ts")
          fi
        fi
        ;;
    esac
  done < "$f"
done

if [ ${#FOUND[@]} -eq 0 ]; then
  echo "[env-expiry] ✅ 만료 관리 시크릿 없음 (OK)"
  exit 0
fi

PASS=1
for entry in "${FOUND[@]}"; do
  IFS='|' read -r file expiry exp_ts <<< "$entry"
  days=$(( (exp_ts - TODAY) / 86400 ))
  if [ "$days" -lt 0 ]; then
    echo "[env-expiry] ❌ EXPIRED: $file — 만료일 $expiry (${days}일 지남)" >&2
    PASS=0
  elif [ "$days" -le "$WARN_DAYS" ]; then
    echo "[env-expiry] ⚠️ WARN: $file — $expiry 까지 ${days}일 남음 (30일 내)"
    if command -v bd >/dev/null 2>&1; then
      bd create "시크릿 만료 임박: $file ($expiry)" -t chore --label secret >/dev/null 2>&1 || true
    fi
  else
    echo "[env-expiry] ✅ OK: $file — $expiry 까지 ${days}일"
  fi
done

if [ "$PASS" -eq 0 ]; then
  echo "[env-expiry] ❌ 만료된 시크릿이 있어 빌드를 중단합니다." >&2
  exit 1
fi
exit 0