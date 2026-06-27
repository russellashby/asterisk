#!/bin/bash
# Builds WordStarMac and wraps it in a double-clickable .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN=".build/$CONFIG/WordStarMac"

APP="WordStar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WordStar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>WordStar</string>
    <key>CFBundleDisplayName</key>     <string>WordStar</string>
    <key>CFBundleIdentifier</key>      <string>com.example.wordstarmac</string>
    <key>CFBundleVersion</key>         <string>0.1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleExecutable</key>      <string>WordStar</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>12.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built $APP"
echo "Run with:  open $APP    (or ./$APP/Contents/MacOS/WordStar)"
