#!/bin/bash
# Create a DMG with TubeKeep.app and /Applications symlink
# Usage: create_dmg.sh [path/to/TubeKeep.app]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_DIR/Info.plist" 2>/dev/null)"
FILENAME="TubeKeep-${VERSION}.dmg"
OUTPUT_DIR="$PROJECT_DIR/Build"

APP_SOURCE="${1:-/tmp/TubeKeep-build/TubeKeep.app}"

if [ ! -d "$APP_SOURCE" ]; then
    echo "❌ App not found at: $APP_SOURCE"
    echo "   Build first: swift build -c release"
    echo "   Or: ./build_and_run.sh release --no-launch"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "📦 Creating DMG: $FILENAME"

STAGING_DIR=$(mktemp -d /tmp/tubekeep-dmg.XXXXXX)
cleanup() { rm -rf "$STAGING_DIR" 2>/dev/null || true; }
trap cleanup EXIT

cp -R "$APP_SOURCE" "$STAGING_DIR/"

VOLUME_NAME="TubeKeep $VERSION"
TMP_DMG="$STAGING_DIR.tmp.dmg"

# Create read-write DMG first
hdiutil create \
  -srcfolder "$STAGING_DIR" \
  -volname "$VOLUME_NAME" \
  -fs HFS+ \
  -format UDRW \
  -megabytes 512 \
  "$TMP_DMG" >/dev/null 2>&1

# Mount and customize
MOUNT_POINT="/Volumes/$VOLUME_NAME"
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen >/dev/null 2>&1

# Add Applications symlink
ln -s /Applications "$MOUNT_POINT/Applications"

# Configure window layout via AppleScript (best effort)
osascript -e "
tell application \"Finder\"
  try
    tell disk \"$VOLUME_NAME\"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {200, 200, 520, 420}
      set theViewOptions to the icon view options of container window
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 96
      set position of item \"TubeKeep.app\" of container window to {100, 120}
      set position of item \"Applications\" of container window to {240, 120}
      close
    end tell
  end try
end tell
" 2>/dev/null || echo "  ⚠️ AppleScript layout skipped"

# Fix permissions and detach
chmod -Rf go-w "$MOUNT_POINT" 2>/dev/null || true
sync
hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true

# Convert to compressed read-only DMG
rm -f "$OUTPUT_DIR/$FILENAME"
hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DIR/$FILENAME" >/dev/null 2>&1

echo "✅ DMG created: $OUTPUT_DIR/$FILENAME ($(du -h "$OUTPUT_DIR/$FILENAME" | cut -f1))"
