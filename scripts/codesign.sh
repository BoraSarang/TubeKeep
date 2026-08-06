#!/bin/bash
# Developer ID signing + Notarization + Staple
# Usage: codesign.sh [path/to/TubeKeep.app] [path/to/output.dmg]
#
# Requires environment variables:
#   APPLE_ID          — Apple Developer account email
#   APPLE_TEAM_ID     — Team ID (e.g. HLQNBZHQQN)
#   APPLE_NOTARY_PWD  — App-specific password (16 chars, xxxx-xxxx-xxxx-xxxx)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_PATH="${1:-/tmp/TubeKeep-build/TubeKeep.app}"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_DIR/Info.plist" 2>/dev/null)"
DMG_PATH="${2:-$PROJECT_DIR/Build/TubeKeep-${VERSION}.dmg}"

# ── Check prerequisites ──
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found: $APP_PATH"
    echo "   Build first: ./build_and_run.sh release --no-launch"
    exit 1
fi

# Find Developer ID certificate
IDENTITY=$(security find-identity -v -p basic 2>&1 | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$IDENTITY" ]; then
    echo "❌ Developer ID Application certificate not found in Keychain."
    echo "   Create one at: https://developer.apple.com/account → Certificates → Developer ID Application"
    echo ""
    echo "   Then run this script again."
    exit 1
fi
echo "🔑 Signing identity: $IDENTITY"

# Check notarization credentials
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_TEAM_ID" ] || [ -z "$APPLE_NOTARY_PWD" ]; then
    echo "⚠️  Notarization credentials not set."
    echo "   Set environment variables to enable notarization:"
    echo "   export APPLE_ID=\"your@email.com\""
    echo "   export APPLE_TEAM_ID=\"YOUR_TEAM_ID\""
    echo "   export APPLE_NOTARY_PWD=\"xxxx-xxxx-xxxx-xxxx\""
    echo ""
    echo "   Skipping notarization. Code-signing only."
    echo ""
    DO_NOTARIZE=false
else
    DO_NOTARIZE=true
fi

# ── Step 1: Codesign the .app bundle ──
echo ""
echo "📝 Step 1/5: Code-signing .app..."

# Remove existing signatures first for clean signing
codesign --remove-signature "$APP_PATH" 2>/dev/null || true

# Sign with hard runtime entitlement for notarization
codesign --force --deep --strict \
    --sign "$IDENTITY" \
    --options runtime \
    "$APP_PATH" 2>&1

echo "   ✅ App signed"

# ── Step 2: Verify signature ──
echo ""
echo "🔍 Step 2/5: Verifying signature..."
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Sealed Resources|runtime" || true
spctl -a -t exec -vv "$APP_PATH" 2>&1 || true
echo "   ✅ Signature verified"

if [ "$DO_NOTARIZE" = false ]; then
    echo ""
    echo "⚠️  Notarization skipped. DMG will not be notarized."
    echo ""
    echo "📦 Signed app ready at: $APP_PATH"
    exit 0
fi

# ── Step 3: Submit to Apple Notary Service ──
echo ""
echo "📤 Step 3/5: Submitting to Apple Notary Service..."
NOTARY_ZIP="/tmp/TubeKeep-notary-${VERSION}.zip"

rm -f "$NOTARY_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"

OUTPUT=$(xcrun notarytool submit "$NOTARY_ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_NOTARY_PWD" \
    --wait 2>&1)

echo "$OUTPUT"

# Extract submission ID
SUBMISSION_ID=$(echo "$OUTPUT" | grep -o "id: [a-f0-9-]\+" | head -1 | cut -d' ' -f2)
if [ -z "$SUBMISSION_ID" ]; then
    echo "❌ Notarization submission failed. Check credentials."
    exit 1
fi
echo "   ✅ Notarization submitted (id: $SUBMISSION_ID)"

# ── Step 4: Staple ticket to .app ──
echo ""
echo "🩹 Step 4/5: Stapling ticket to .app..."
xcrun stapler staple "$APP_PATH" 2>&1
echo "   ✅ Ticket stapled"

# ── Step 5: Sign + staple DMG ──
echo ""
echo "📀 Step 5/5: Signing DMG..."
if [ -f "$DMG_PATH" ]; then
    codesign --force --sign "$IDENTITY" "$DMG_PATH" 2>&1
    xcrun stapler staple "$DMG_PATH" 2>&1
    echo "   ✅ DMG signed and stapled"
else
    echo "   ⚠️  DMG not found at $DMG_PATH — skipping DMG signing"
    echo "   Run 'make release' or create DMG separately"
fi

# Cleanup
rm -f "$NOTARY_ZIP"

echo ""
echo "🎉 All done! Signed and notarized:"
echo "   $APP_PATH"
[ -f "$DMG_PATH" ] && echo "   $DMG_PATH"
