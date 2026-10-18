#!/usr/bin/env bash
#
# Xcode-less build: compiles with SwiftPM, then assembles build/Caffeine.app.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/Caffeine.app"

VERSION="${CAFFEINE_VERSION:-$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)}"
VERSION="${VERSION#v}"
VERSION="${VERSION:-0.0.0}"
BUILD="${CAFFEINE_BUILD:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || true)}"
BUILD="${BUILD:-1}"

echo "==> swift build ($CONFIG)"
swift build --package-path "$ROOT" -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/Caffeine"
if [[ ! -x "$BIN" ]]; then
    echo "error: executable not found at $BIN" >&2
    exit 1
fi

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Caffeine"

RESOURCES="$APP/Contents/Resources"
cp "$ROOT/assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT/assets/coffee-enabled-imgset/ion-coffee.png"     "$RESOURCES/coffee-enabled.png"
cp "$ROOT/assets/coffee-enabled-imgset/ion-coffee@2x.png"  "$RESOURCES/coffee-enabled@2x.png"
cp "$ROOT/assets/coffee-enabled-imgset/ion-coffee@3x.png"  "$RESOURCES/coffee-enabled@3x.png"
cp "$ROOT/assets/coffee-disabled-imgset/ion-coffee.png"    "$RESOURCES/coffee-disabled.png"
cp "$ROOT/assets/coffee-disabled-imgset/ion-coffee@2x.png" "$RESOURCES/coffee-disabled@2x.png"
cp "$ROOT/assets/coffee-disabled-imgset/ion-coffee@3x.png" "$RESOURCES/coffee-disabled@3x.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Caffeine</string>
	<key>CFBundleExecutable</key>
	<string>Caffeine</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.cheems.caffeine</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Caffeine</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> codesigning (ad-hoc)"
codesign --force --sign - "$APP"

echo
echo "Built: $APP"
echo "Run:   open \"$APP\""
