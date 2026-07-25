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

# ffmpeg + ffprobe
if [ -f "$CACHE_DIR/ffmpeg" ] && [ -f "$CACHE_DIR/ffprobe" ]; then
    cp "$CACHE_DIR/ffmpeg" "$RESOURCES_DIR/ffmpeg"
    cp "$CACHE_DIR/ffprobe" "$RESOURCES_DIR/ffprobe"
    echo "📦 ffmpeg + ffprobe from cache"
else
    echo "⬇️  Downloading ffmpeg + ffprobe (static)..."
    mkdir -p "$CACHE_DIR"
    for BIN in ffmpeg ffprobe; do
        URL="https://evermeet.cx/ffmpeg/getrelease/$BIN/zip"
        TMP_ZIP="/tmp/${BIN}_$$.zip"
        if curl -# -f -JL -o "$TMP_ZIP" "$URL"; then
            TMP_DIR="/tmp/${BIN}_extract_$$"
            mkdir -p "$TMP_DIR"
            unzip -o "$TMP_ZIP" -d "$TMP_DIR" &> /dev/null
            BIN_PATH="$TMP_DIR/$BIN"
            if [ -f "$BIN_PATH" ]; then
                cp "$BIN_PATH" "$CACHE_DIR/$BIN"
                chmod +x "$CACHE_DIR/$BIN"
                cp "$CACHE_DIR/$BIN" "$RESOURCES_DIR/$BIN"
                echo "✅ $BIN downloaded ($(du -h "$CACHE_DIR/$BIN" | cut -f1))"
            else
                echo "⚠️  $BIN not found in zip"
            fi
            rm -rf "$TMP_ZIP" "$TMP_DIR"
        else
            rm -f "$TMP_ZIP"
            echo "⚠️  $BIN download failed, trying system..."
            if command -v "$BIN" &> /dev/null; then
                cp "$(command -v "$BIN")" "$RESOURCES_DIR/$BIN"
                echo "📦 $BIN bundled from system"
            else
                echo "❌ $BIN not found. Please install: brew install ffmpeg"
                exit 1
            fi
        fi
    done
fi

# whisper.cpp (optional — for local AI subtitles)
WHISPER_BIN="whisper-cli"

# Dynamically find libwhisper from Homebrew
WHISPER_LIB=""
for libpath in /opt/homebrew/lib/libwhisper.1.dylib /usr/local/lib/libwhisper.1.dylib; do
    [ -f "$libpath" ] && { WHISPER_LIB="$libpath"; break; }
done
if [ -z "$WHISPER_LIB" ] && command -v brew &>/dev/null; then
    WHISPER_LIB="$(brew --prefix whisper-cpp 2>/dev/null)/lib/libwhisper.1.dylib"
    [ ! -f "$WHISPER_LIB" ] && WHISPER_LIB=""
fi

fix_whisper_binary() {
    local bin="$1"
    [ ! -f "$bin" ] && return
    if otool -L "$bin" 2>/dev/null | grep -q "@rpath/libwhisper"; then
        if [ -n "$WHISPER_LIB" ]; then
            install_name_tool -change @rpath/libwhisper.1.dylib "$WHISPER_LIB" "$bin" 2>&1 | grep -v "warning" || true
        else
            echo "⚠️  libwhisper.dylib not found, whisper-cli may not work"
        fi
    fi
    codesign -f -s - "$bin" 2>/dev/null || true
}

if [ -f "$CACHE_DIR/$WHISPER_BIN" ]; then
    cp "$CACHE_DIR/$WHISPER_BIN" "$RESOURCES_DIR/$WHISPER_BIN"
    fix_whisper_binary "$RESOURCES_DIR/$WHISPER_BIN"
    echo "📦 whisper from cache"
else
    WHISPER_SRC=""
    for p in /opt/homebrew/bin/whisper-cli /usr/local/bin/whisper-cli; do
        [ -x "$p" ] && { WHISPER_SRC="$p"; break; }
    done
    if [ -z "$WHISPER_SRC" ] && command -v brew &>/dev/null; then
        echo "⬇️  Installing whisper-cpp via Homebrew..."
        brew install whisper-cpp 2>&1 | tail -3
        [ -x /opt/homebrew/bin/whisper-cli ] && WHISPER_SRC="/opt/homebrew/bin/whisper-cli"
    fi
    if [ -n "$WHISPER_SRC" ]; then
        cp "$WHISPER_SRC" "$RESOURCES_DIR/$WHISPER_BIN"
        cp "$WHISPER_SRC" "$CACHE_DIR/$WHISPER_BIN"
        chmod +x "$RESOURCES_DIR/$WHISPER_BIN"
        fix_whisper_binary "$RESOURCES_DIR/$WHISPER_BIN"
        fix_whisper_binary "$CACHE_DIR/$WHISPER_BIN"
        echo "✅ whisper bundled ($(du -h "$RESOURCES_DIR/$WHISPER_BIN" | cut -f1))"
    else
        echo "⚠️  whisper not available. Run: brew install whisper-cpp"
        echo "   Local AI subtitles will be unavailable without it."
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
codesign --force --deep --sign - "$INSTALL_DIR/TubeKeep.app" 2>/dev/null || true

echo ""
echo "🚀 Launching TubeKeep..."
open "$INSTALL_DIR/TubeKeep.app"
