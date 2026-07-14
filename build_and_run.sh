#!/bin/bash
set -e

# Terminate any running instance first
pkill -f "VideoDownloader" 2>/dev/null || true

BUILD_MODE="${1:-release}"

if [ "$BUILD_MODE" != "release" ] && [ "$BUILD_MODE" != "debug" ]; then
    echo "Usage: $0 [release|debug]"
    echo "  default: release"
    exit 1
fi

BUNDLE_NAME="VideoDownloader"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="/tmp/VideoDownloader-build/$BUNDLE_NAME.app"

echo "🔨 Building ($BUILD_MODE)..."
cd "$PROJECT_DIR"

if [ "$BUILD_MODE" = "debug" ]; then
    swift build -c debug
    EXECUTABLE="$BUILD_DIR/debug/MDownload"
else
    swift build -c release
    EXECUTABLE="$BUILD_DIR/release/MDownload"
fi

echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/VideoDownloader"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Copy localizations
for lang in en ko; do
    SRC="$PROJECT_DIR/Resources/$lang.lproj"
    if [ -d "$SRC" ]; then
        cp -r "$SRC" "$APP_BUNDLE/Contents/Resources/"
    fi
done

# Bundle external dependencies
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
CACHE_DIR="$PROJECT_DIR/.build_cache"

# yt-dlp: install as Python library via pip, then create launcher script
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
            # Create launcher script that finds Python at runtime
            cat > "$CACHE_DIR/yt-dlp-launcher" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
PYTHON=""
# 우선순위: Homebrew → MacPorts → Xcode/usr → PATH
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
                echo "📦 yt-dlp bundled from system (Python script, may have path issues)"
            else
                echo "⬇️  Falling back to standalone yt-dlp (may be slow)..."
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
            echo "⬇️  Falling back to standalone yt-dlp (may be slow)..."
            curl -# -f -L -o "$RESOURCES_DIR/yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
            chmod +x "$RESOURCES_DIR/yt-dlp"
        fi
    fi
fi

# ffmpeg: static build from evermeet.cx (fully self-contained, no dylib deps)
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
            echo "📦 ffmpeg bundled from system (may have library issues on other Macs)"
        else
            echo "❌ ffmpeg not found. Please install: brew install ffmpeg"
            exit 1
        fi
    fi
fi

# Install to ~/Applications/ (no sudo needed, TCC-free, Spotlight-searchable)
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
INSTALL_PATH="$INSTALL_DIR/$BUNDLE_NAME.app"
rm -rf "$INSTALL_PATH"
cp -R "$APP_BUNDLE" "$INSTALL_PATH"
echo "✅ Installed: $INSTALL_PATH"
echo ""
echo "🚀 Launching..."
open "$INSTALL_PATH"
