#!/bin/bash
# Builds the app and wraps it in a double-clickable Asterisk.app bundle.
# (The SwiftPM executable target is still named WordStarMac; the shipped
# product is "Asterisk".)
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN=".build/$CONFIG/WordStarMac"

APP="Asterisk.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Asterisk"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Asterisk</string>
    <key>CFBundleDisplayName</key>     <string>Asterisk</string>
    <key>CFBundleIdentifier</key>      <string>com.russellashby.asterisk</string>
    <key>CFBundleVersion</key>         <string>0.1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleExecutable</key>      <string>Asterisk</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>12.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built $APP"
echo "Run with:  open $APP    (or ./$APP/Contents/MacOS/Asterisk)"
