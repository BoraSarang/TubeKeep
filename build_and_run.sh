#!/bin/bash
# build_and_run.sh — v1.6 dispatcher
# Usage: ./build_and_run.sh [debug|release] [macos|clean] [--no-launch]
set -e

APP_NAME="TubeKeep"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[build_and_run]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

MODE="debug"
PLATFORM="auto"
NO_LAUNCH=false
DO_CLEAN=false

for arg in "$@"; do
  case $arg in
    debug|release) MODE="$arg" ;;
    macos|ios|android|web|all) PLATFORM="$arg" ;;
    --clean) DO_CLEAN=true ;;
    --no-launch) NO_LAUNCH=true ;;
    -h|--help)
      echo "Usage: ./build_and_run.sh [debug|release] [macos|clean] [--no-launch]"
      echo ""
      echo "  debug|release     Build mode (default: debug)"
      echo "  macos             Target platform (default: auto-detect)"
      echo "  clean|--clean     Clean build"
      echo "  --no-launch       Build only, don't launch"
      echo "  --help            Show this help"
      exit 0 ;;
  esac
done

# Platform auto-detect
if [ "$PLATFORM" = "auto" ]; then
  if [ -d "ios" ] || ls *.xcworkspace 2>/dev/null | head -1 > /dev/null 2>&1; then PLATFORM="ios"; fi
  if [ -d "android" ]; then PLATFORM="android"; fi
  if [ -f "package.json" ]; then PLATFORM="web"; fi
  # Default to macos for this project
  PLATFORM="macos"
fi

run_platform() {
  local p=$1
  log "▶ $p $MODE build (clean=$DO_CLEAN no_launch=$NO_LAUNCH)"
  case $p in
    macos)
      "$SCRIPT_DIR/scripts/build-macos.sh" "$MODE" "$DO_CLEAN"
      if [ "$NO_LAUNCH" = false ]; then
        log "🔄 Killing existing $APP_NAME..."
        pkill -x "$APP_NAME" 2>/dev/null || true
        sleep 0.3
        log "🚀 Launching $APP_NAME..."
        open "$HOME/Applications/$APP_NAME.app"
      else
        log "📦 App bundle: $HOME/Applications/$APP_NAME.app"
      fi
      ;;
    *)
      error "Platform '$p' not supported yet"
      exit 1 ;;
  esac
}

if [ "$PLATFORM" = "all" ]; then
  for p in macos; do
    [ -f "$SCRIPT_DIR/scripts/build-$p.sh" ] && run_platform $p
  done
else
  run_platform $PLATFORM
fi

log "완료: $PLATFORM $MODE"
