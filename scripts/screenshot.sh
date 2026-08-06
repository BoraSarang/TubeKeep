#!/bin/bash
# AGENTS.md v1.9 standard: screenshot.sh
# Usage: ./scripts/screenshot.sh [macos|ios|android|web]
# Saves to: docs/screenshots/{platform}/v{version}_{screenName}.png

set -e

PLATFORM="${1:-macos}"
VERSION="2.8.0"
SCREENS_DIR="docs/screenshots/${PLATFORM}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SCREENS_DIR"

case "$PLATFORM" in
  macos)
    # Captures frontmost window (TubeKeep app window)
    if ! command -v screencapture >/dev/null 2>&1; then
      echo "❌ screencapture not found" >&2
      exit 1
    fi
    # Use interactive selection to capture the right window
    screencapture -o "${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    echo "✅ Screenshot saved: ${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    ;;
  ios)
    if ! command -v xcrun >/dev/null 2>&1; then
      echo "❌ xcrun not found (requires Xcode)" >&2
      exit 1
    fi
    xcrun simctl io booted screenshot "${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    echo "✅ Screenshot saved: ${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    ;;
  android)
    if ! command -v adb >/dev/null 2>&1; then
      echo "❌ adb not found (requires Android SDK)" >&2
      exit 1
    fi
    adb exec-out screencap -p > "${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    echo "✅ Screenshot saved: ${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    ;;
  web)
    if ! command -v npx >/dev/null 2>&1; then
      echo "❌ npx not found" >&2
      exit 1
    fi
    npx playwright screenshot --url http://localhost:3000 "${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    echo "✅ Screenshot saved: ${SCREENS_DIR}/v${VERSION}_${TIMESTAMP}.png"
    ;;
  *)
    echo "Usage: $0 [macos|ios|android|web]"
    exit 1
    ;;
esac
