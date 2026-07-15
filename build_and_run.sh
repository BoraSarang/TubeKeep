#!/bin/bash
set -e

# Terminate any running instances
pkill -f "TubeKeep" 2>/dev/null || true

BUILD_MODE="${1:-release}"
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=true ;;
    esac
done

if [ "$BUILD_MODE" != "release" ] && [ "$BUILD_MODE" != "debug" ]; then
    echo "Usage: $0 [release|debug] [--clean]"
    echo "  default: release"
    echo "  --clean: run 'swift package clean' before build"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"

cd "$PROJECT_DIR"
$CLEAN && echo "🧹 Cleaning..." && swift package clean

echo "🔨 Building ($BUILD_MODE)..."

if [ "$BUILD_MODE" = "debug" ]; then
    swift build -c debug
    EXECUTABLE="$BUILD_DIR/debug/TubeKeep"
else
    swift build -c release
    EXECUTABLE="$BUILD_DIR/release/TubeKeep"
fi

APP_BUNDLE_BASE="/tmp/TubeKeep-build"
rm -rf "$APP_BUNDLE_BASE"

# ──────────────────────────────────────────────
# Main app: TubeKeep.app
# ──────────────────────────────────────────────
echo "📦 Creating TubeKeep.app..."
MAIN_BUNDLE="$APP_BUNDLE_BASE/TubeKeep.app"
mkdir -p "$MAIN_BUNDLE/Contents/MacOS"
mkdir -p "$MAIN_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$MAIN_BUNDLE/Contents/MacOS/TubeKeep"
cp "$PROJECT_DIR/Info.plist" "$MAIN_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/AppIcon.icns" "$MAIN_BUNDLE/Contents/Resources/"

for lang in en ko; do
    SRC="$PROJECT_DIR/Resources/$lang.lproj"
    if [ -d "$SRC" ]; then
        cp -r "$SRC" "$MAIN_BUNDLE/Contents/Resources/"
    fi
done

RESOURCES_DIR="$MAIN_BUNDLE/Contents/Resources"
CACHE_DIR="$PROJECT_DIR/.build_cache"

# yt-dlp
mkdir -p "$CACHE_DIR"
if [ -d "$CACHE_DIR/yt-dlp-lib" ]; then
    cp -r "$CACHE_DIR/yt-dlp-lib" "$RESOURCES_DIR/yt-dlp-lib"
    cp "$CACHE_DIR/yt-dlp-launcher" "$RESOURCES_DIR/yt-dlp"
    echo "📦 yt-dlp from cache"
else
    echo "⬇️  Installing yt-dlp (pip install --target)..."
    PYTHON=""
    for p in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        if [ -x "$p" ]; then PYTHON="$p"; break; fi
    done
    if [ -z "$PYTHON" ]; then PYTHON=$(command -v python3 2>/dev/null || true); fi
    if [ -n "$PYTHON" ]; then
        rm -rf "$CACHE_DIR/yt-dlp-lib"
        if $PYTHON -m pip install --target "$CACHE_DIR/yt-dlp-lib" yt-dlp 2>&1 | tail -3; then
            cp -r "$CACHE_DIR/yt-dlp-lib" "$RESOURCES_DIR/yt-dlp-lib"
            cat > "$CACHE_DIR/yt-dlp-launcher" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
PYTHON=""
for p in /opt/homebrew/bin/python3 /usr/local/bin/python3 /opt/local/bin/python3 /usr/bin/python3; do
    [ -x "$p" ] && { PYTHON="$p"; break; }
done
[ -z "$PYTHON" ] && PYTHON=$(command -v python3 2>/dev/null)
if [ -z "$PYTHON" ]; then
    echo "yt-dlp requires Python 3" >&2
    exit 1
fi
export PYTHONPATH="$SCRIPT_DIR/yt-dlp-lib${PYTHONPATH:+:$PYTHONPATH}"
exec "$PYTHON" -m yt_dlp "$@"
LAUNCHER
            chmod +x "$CACHE_DIR/yt-dlp-launcher"
            cp "$CACHE_DIR/yt-dlp-launcher" "$RESOURCES_DIR/yt-dlp"
            echo "✅ yt-dlp installed (Python library + launcher)"
        else
            echo "⚠️  pip install failed, trying system binary..."
            if command -v yt-dlp &> /dev/null; then
                cp "$(command -v yt-dlp)" "$RESOURCES_DIR/yt-dlp"
                chmod +x "$RESOURCES_DIR/yt-dlp"
                echo "📦 yt-dlp bundled from system"
            else
                echo "⬇️  Falling back to standalone yt-dlp..."
                curl -# -f -L -o "$RESOURCES_DIR/yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
                chmod +x "$RESOURCES_DIR/yt-dlp"
            fi
        fi
    else
        echo "⚠️  Python 3 not found, trying system yt-dlp..."
        if command -v yt-dlp &> /dev/null; then
            cp "$(command -v yt-dlp)" "$RESOURCES_DIR/yt-dlp"
            chmod +x "$RESOURCES_DIR/yt-dlp"
        else
            echo "⬇️  Falling back to standalone yt-dlp..."
            curl -# -f -L -o "$RESOURCES_DIR/yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
            chmod +x "$RESOURCES_DIR/yt-dlp"
        fi
    fi
fi

# ffmpeg
if [ -f "$CACHE_DIR/ffmpeg" ]; then
    cp "$CACHE_DIR/ffmpeg" "$RESOURCES_DIR/ffmpeg"
    echo "📦 ffmpeg from cache"
else
    echo "⬇️  Downloading ffmpeg (static)..."
    FFMPEG_URL="https://evermeet.cx/ffmpeg/getrelease/zip"
    TMP_ZIP="/tmp/ffmpeg_$$.zip"
    mkdir -p "$CACHE_DIR"
    if curl -# -f -JL -o "$TMP_ZIP" "$FFMPEG_URL"; then
        TMP_DIR="/tmp/ffmpeg_extract_$$"
        mkdir -p "$TMP_DIR"
        unzip -o "$TMP_ZIP" -d "$TMP_DIR" &> /dev/null
        FFMPEG_BIN="$TMP_DIR/ffmpeg"
        if [ -f "$FFMPEG_BIN" ]; then
            cp "$FFMPEG_BIN" "$CACHE_DIR/ffmpeg"
            chmod +x "$CACHE_DIR/ffmpeg"
            cp "$CACHE_DIR/ffmpeg" "$RESOURCES_DIR/ffmpeg"
            echo "✅ ffmpeg downloaded ($(du -h "$CACHE_DIR/ffmpeg" | cut -f1))"
        else
            echo "⚠️  ffmpeg binary not found in zip"
        fi
        rm -rf "$TMP_ZIP" "$TMP_DIR"
    else
        rm -f "$TMP_ZIP"
        echo "⚠️  Download failed, trying system ffmpeg..."
        if command -v ffmpeg &> /dev/null; then
            cp "$(command -v ffmpeg)" "$RESOURCES_DIR/ffmpeg"
            chmod +x "$RESOURCES_DIR/ffmpeg"
            echo "📦 ffmpeg bundled from system"
        else
            echo "❌ ffmpeg not found. Please install: brew install ffmpeg"
            exit 1
        fi
    fi
fi

# ──────────────────────────────────────────────
# Install to ~/Applications/
# ──────────────────────────────────────────────
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

rm -rf "$INSTALL_DIR/TubeKeep.app"
cp -R "$MAIN_BUNDLE" "$INSTALL_DIR/TubeKeep.app"

echo "✅ Installed: $INSTALL_DIR/TubeKeep.app"

# Ad-hoc sign to suppress Gatekeeper "Intel 미지원" warning (ARM64-only build)
codesign --force --deep --sign - "$INSTALL_DIR/TubeKeep.app" 2>/dev/null

echo ""
echo "🚀 Launching TubeKeep..."
open "$INSTALL_DIR/TubeKeep.app"
