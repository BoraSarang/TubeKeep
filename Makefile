APP_PATH = $(HOME)/Applications/TubeKeep.app
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null)

.PHONY: build run release release-dmg release-upload release-skip-build codesign notarize clean

default: run

build:
	./build_and_run.sh debug

run:
	./build_and_run.sh debug

# ── Build + DMG + GitHub Release (full pipeline) ──
release:
	./build_and_run.sh release --no-launch
	./Tools/create_dmg.sh
	@echo ""
	@echo "🚀 Ready to release v$(VERSION)"
	@echo "   Run 'make release-upload' to upload to GitHub Releases"
	@echo "   Run 'make notarize' to sign + notarize"

# ── DMG only from existing .app at /tmp/TubeKeep-build/ ──
release-dmg:
	./Tools/create_dmg.sh

# ── Upload DMG to GitHub Releases ──
release-upload:
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Could not read version from Info.plist"; exit 1; fi
	@DMG=$$(ls -t Build/TubeKeep-*.dmg 2>/dev/null | head -1); \
	if [ -z "$$DMG" ]; then \
		echo "❌ No DMG found in Build/. Run 'make release' first."; exit 1; fi; \
	echo "🚀 Uploading $$DMG to GitHub Release v$(VERSION)..."; \
	gh release create "v$(VERSION)" "$$DMG" --generate-notes --title "v$(VERSION)" 2>&1 || \
	gh release upload "v$(VERSION)" "$$DMG" 2>&1

# ── Sign + Notarize (requires Developer ID cert + notary credentials) ──
codesign:
	./Tools/codesign.sh

notarize:
	./Tools/codesign.sh

# ── Full signed release chain ──
release-signed:
	./build_and_run.sh release --no-launch
	./Tools/codesign.sh
	./Tools/create_dmg.sh
	./Tools/codesign.sh /tmp/TubeKeep-build/TubeKeep.app Build/TubeKeep-$(VERSION).dmg
	@echo ""
	@echo "🚀 Signed release v$(VERSION) ready"

# ── Build + .zip (no DMG) ──
release-zip:
	./build_and_run.sh release --no-launch
	@VERSION=$$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null); \
	ZIP="/tmp/TubeKeep-build/TubeKeep-$$VERSION.zip"; \
	cd /tmp/TubeKeep-build; \
	zip -r "$$ZIP" TubeKeep.app; \
	echo "📦 $$ZIP ($$(du -h "$$ZIP" | cut -f1))"

# ── Skip build, use existing .app in /tmp/TubeKeep-build/ ──
release-skip-build: release-dmg

# ── Only sign (no build, no dmg) ──
sign-only:
	./Tools/codesign.sh

clean:
	swift package clean
