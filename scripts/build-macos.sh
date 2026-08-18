#!/bin/bash
# macOS build script — called by build_and_run.sh dispatcher
# Usage: ./scripts/build-macos.sh [debug|release] [true|false] (MODE, CLEAN)
set -e

MODE="${1:-debug}"
CLEAN="${2:-false}"

APP_NAME="TubeKeep"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"

# Code signing identity — Apple Dev 인증서(안정적 TCC 식별). 없으면 ad-hoc 폴백.
CODE_SIGN_IDENTITY="Apple Development: leeborasarang@gmail.com (HLQNBZHQQN)"
if ! security find-identity -p codesigning -v 2>/dev/null | grep -q "HLQNBZHQQN"; then
    CODE_SIGN_IDENTITY="-"
    echo "⚠️  Apple Development 인증서 없음 — ad-hoc 서명 사용 (TCC 권한이 매번 초기화될 수 있음)"
fi

cd "$PROJECT_DIR"

# Kill existing app and its children
for pid in $(pgrep -x "$APP_NAME" 2>/dev/null); do
  pkill -9 -P "$pid" 2>/dev/null || true
done
pkill -9 "$APP_NAME" 2>/dev/null || true
killall "$APP_NAME" 2>/dev/null || true

$CLEAN && echo "🧹 Cleaning..." && swift package clean

echo "🔨 Building ($MODE)..."

if [ "$MODE" = "debug" ]; then
    swift build -c debug
    EXECUTABLE="$BUILD_DIR/debug/$APP_NAME"
else
    swift build -c release
    EXECUTABLE="$BUILD_DIR/release/$APP_NAME"
fi

APP_BUNDLE_BASE="/tmp/$APP_NAME-build"
rm -rf "$APP_BUNDLE_BASE"

echo "📦 Creating $APP_NAME.app..."
MAIN_BUNDLE="$APP_BUNDLE_BASE/$APP_NAME.app"
mkdir -p "$MAIN_BUNDLE/Contents/MacOS"
mkdir -p "$MAIN_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$MAIN_BUNDLE/Contents/MacOS/$APP_NAME"
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

# yt-dlp (python-build-standalone + yt-dlp-lib — 샌드박스 호환)
mkdir -p "$CACHE_DIR"
if [ -x "$CACHE_DIR/python3.13/bin/python3.13" ]; then
    cp -R "$CACHE_DIR/python3.13" "$RESOURCES_DIR/python3.13"
    echo "📦 Python 3.13 standalone from cache"
else
    echo "⬇️  Downloading python-build-standalone 3.13 (샌드박스용 Python 런타임)..."
    if curl -# -f -L -o "$CACHE_DIR/cpython.tar.gz" "https://github.com/astral-sh/python-build-standalone/releases/download/20260814/cpython-3.13.15+20260814-aarch64-apple-darwin-install_only.tar.gz" 2>&1 | tail -1; then
        rm -rf "$CACHE_DIR/python3.13"
        tar -xzf "$CACHE_DIR/cpython.tar.gz" -C "$CACHE_DIR"
        mv "$CACHE_DIR/python" "$CACHE_DIR/python3.13"
        cp -R "$CACHE_DIR/python3.13" "$RESOURCES_DIR/python3.13"
        echo "✅ Python 3.13 standalone bundled"
    else
        echo "❌ python-build-standalone download failed"
    fi
fi

if [ -d "$CACHE_DIR/yt-dlp-lib" ]; then
    cp -r "$CACHE_DIR/yt-dlp-lib" "$RESOURCES_DIR/yt-dlp-lib"
    echo "📦 yt-dlp-lib from cache"
else
    echo "⬇️  Installing yt-dlp-lib (pip install --target)..."
    PYTHON=""
    for p in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        if [ -x "$p" ]; then PYTHON="$p"; break; fi
    done
    if [ -z "$PYTHON" ]; then PYTHON=$(command -v python3 2>/dev/null || true); fi
    if [ -n "$PYTHON" ]; then
        rm -rf "$CACHE_DIR/yt-dlp-lib"
        if $PYTHON -m pip install --target "$CACHE_DIR/yt-dlp-lib" yt-dlp 2>&1 | tail -2; then
            cp -r "$CACHE_DIR/yt-dlp-lib" "$RESOURCES_DIR/yt-dlp-lib"
            echo "✅ yt-dlp-lib installed (pip)"
        else
            echo "❌ pip install yt-dlp failed"
        fi
    else
        echo "❌ Python 3 not found (pip install 불가)"
    fi
fi

# deno — yt-dlp JS 런타임 (YouTube PO Token/서명 처리, 403 방지)
DENO_BIN="$(command -v deno 2>/dev/null || true)"
if [ -z "$DENO_BIN" ]; then
    for d in /opt/homebrew/Cellar/deno/*/bin/deno /usr/local/Cellar/deno/*/bin/deno; do
        [ -x "$d" ] && { DENO_BIN="$d"; break; }
    done
fi
if [ -n "$DENO_BIN" ]; then
    if [ -x "$CACHE_DIR/deno/deno" ]; then
        cp -R "$CACHE_DIR/deno/." "$RESOURCES_DIR/"
        echo "📦 deno from cache ($(du -h "$RESOURCES_DIR/deno" | cut -f1))"
    else
        echo "⬇️  deno 번들 생성 ($DENO_BIN)"
        rm -rf "$CACHE_DIR/deno"
        mkdir -p "$CACHE_DIR/deno/deno-libs"
        cp "$DENO_BIN" "$CACHE_DIR/deno/deno"
        while IFS= read -r LIB; do
            [ -z "$LIB" ] && continue
            LIBNAME="$(basename "$LIB")"
            cp "$LIB" "$CACHE_DIR/deno/deno-libs/" 2>/dev/null || true
            install_name_tool -change "$LIB" "@loader_path/deno-libs/$LIBNAME" "$CACHE_DIR/deno/deno" 2>/dev/null || true
        done < <(otool -L "$DENO_BIN" 2>/dev/null | rg -o "/opt/homebrew/[^ ]+\.dylib|/usr/local/[^ ]+\.dylib" || true)
        cp -R "$CACHE_DIR/deno/." "$RESOURCES_DIR/"
        echo "✅ deno bundled (JS 런타임)"
    fi
else
    echo "⚠️  deno 없음 — YouTube 다운로드 403 위험. brew install deno"
fi

cat > "$RESOURCES_DIR/yt-dlp" << 'LAUNCHER'
#!/bin/bash
# 샌드박스 호환 yt-dlp launcher — 번들 Python + 번들 yt-dlp-lib + 컨테이너 TMPDIR + deno JS 런타임
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"
if [ -z "$TMPDIR" ] || [ ! -w "$TMPDIR" ]; then
    export TMPDIR="$HOME/Library/Containers/com.borasarang.tubekeep/Data/tmp"
    mkdir -p "$TMPDIR" 2>/dev/null
fi
cd "$TMPDIR" 2>/dev/null || true
PYTHON="$SCRIPT_DIR/python3.13/bin/python3.13"
if [ ! -x "$PYTHON" ]; then
    echo "번들 Python을 찾을 수 없습니다: $PYTHON" >&2
    exit 1
fi
export PYTHONPATH="$SCRIPT_DIR/yt-dlp-lib${PYTHONPATH:+:$PYTHONPATH}"
if [ -x "$SCRIPT_DIR/deno" ]; then
    export DENO_DIR="$TMPDIR/deno"
    exec "$PYTHON" -m yt_dlp --js-runtimes "deno:$SCRIPT_DIR/deno" "$@"
else
    exec "$PYTHON" -m yt_dlp "$@"
fi
LAUNCHER
chmod +x "$RESOURCES_DIR/yt-dlp"
echo "✅ yt-dlp launcher 작성 완료"

# ffmpeg + ffprobe
if [ -f "$CACHE_DIR/ffmpeg" ] && [ -f "$CACHE_DIR/ffprobe" ]; then
    cp "$CACHE_DIR/ffmpeg" "$RESOURCES_DIR/ffmpeg"
    cp "$CACHE_DIR/ffprobe" "$RESOURCES_DIR/ffprobe"
    echo "📦 ffmpeg + ffprobe from cache"
else
    echo "⬇️  Downloading ffmpeg + ffprobe (static)..."
    mkdir -p "$CACHE_DIR"
    HOST_ARCH="$(uname -m)"
    for BIN in ffmpeg ffprobe; do
        if [ "$HOST_ARCH" = "arm64" ]; then
            URL="https://www.osxexperts.net/${BIN}9arm.zip"
        else
            URL="https://evermeet.cx/ffmpeg/getrelease/$BIN/zip"
        fi
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

# whisper.cpp
WHISPER_BIN="whisper-cli"
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
    codesign -f -s "$CODE_SIGN_IDENTITY" "$bin" 2>/dev/null || true
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
    fi
fi

# Bundle libmpv
LIBMPV_SRC="/opt/homebrew/opt/mpv/lib/libmpv.2.dylib"
if [ -f "$LIBMPV_SRC" ]; then
    mkdir -p "$MAIN_BUNDLE/Contents/Frameworks"
    cp "$LIBMPV_SRC" "$MAIN_BUNDLE/Contents/Frameworks/libmpv.2.dylib"
    chmod 755 "$MAIN_BUNDLE/Contents/Frameworks/libmpv.2.dylib"
    install_name_tool -id @rpath/libmpv.2.dylib "$MAIN_BUNDLE/Contents/Frameworks/libmpv.2.dylib" 2>/dev/null || true
    install_name_tool -change /opt/homebrew/opt/mpv/lib/libmpv.2.dylib @rpath/libmpv.2.dylib "$MAIN_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    install_name_tool -add_rpath @loader_path/../Frameworks "$MAIN_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    codesign --force --sign "$CODE_SIGN_IDENTITY" "$MAIN_BUNDLE/Contents/Frameworks/libmpv.2.dylib" 2>/dev/null || true
    echo "📦 libmpv embedded ($(du -h "$MAIN_BUNDLE/Contents/Frameworks/libmpv.2.dylib" | cut -f1))"
fi

# Sign embedded resource binaries individually (avoids --deep overwriting widget entitlements)
for BIN in ffmpeg ffprobe whisper-cli deno; do
    if [ -f "$RESOURCES_DIR/$BIN" ]; then
        codesign --force --sign "$CODE_SIGN_IDENTITY" "$RESOURCES_DIR/$BIN" 2>/dev/null || true
    fi
done
for LIB in "$RESOURCES_DIR/deno-libs/"*.dylib; do
    [ -f "$LIB" ] && codesign --force --sign "$CODE_SIGN_IDENTITY" "$LIB" 2>/dev/null || true
done

# Install
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$MAIN_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
echo "✅ Installed: $INSTALL_DIR/$APP_NAME.app"

# Build widget extension
WIDGET_NAME="TubeKeepWidget"
echo "🔨 Building widget extension..."
if [ "$MODE" = "debug" ]; then
    swift build -c debug --target "$WIDGET_NAME"
    WIDGET_EXEC="$BUILD_DIR/debug/$WIDGET_NAME"
else
    swift build -c release --target "$WIDGET_NAME"
    WIDGET_EXEC="$BUILD_DIR/release/$WIDGET_NAME"
fi
WIDGET_BUNDLE="$INSTALL_DIR/$APP_NAME.app/Contents/PlugIns/$WIDGET_NAME.appex"
mkdir -p "$WIDGET_BUNDLE/Contents/MacOS"
cp "$WIDGET_EXEC" "$WIDGET_BUNDLE/Contents/MacOS/$WIDGET_NAME"
cp "$PROJECT_DIR/Info-Widget.plist" "$WIDGET_BUNDLE/Contents/Info.plist"
codesign --force --sign "$CODE_SIGN_IDENTITY" --entitlements "$PROJECT_DIR/Entitlements/TubeKeepWidget.entitlements" "$WIDGET_BUNDLE" 2>/dev/null || true
echo "📦 Widget embedded: $WIDGET_BUNDLE"

codesign --force --sign "$CODE_SIGN_IDENTITY" --entitlements "$PROJECT_DIR/Entitlements/TubeKeep.entitlements" "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo "[build] macOS $MODE DebugPanel: $([ "$MODE" = debug ] && echo ON || echo OFF)"
