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
    <key>CFBundleVersion</key>         <string>0.4</string>
    <key>CFBundleShortVersionString</key><string>0.4</string>
    <key>CFBundleExecutable</key>      <string>Asterisk</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>12.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>  <string>com.russellashby.asterisk.document</string>
            <key>UTTypeDescription</key> <string>Asterisk Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.content</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>asterisk</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>      <string>Asterisk Document</string>
            <key>CFBundleTypeRole</key>      <string>Editor</string>
            <key>LSHandlerRank</key>         <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.russellashby.asterisk.document</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Ad-hoc code-sign the whole bundle. The Swift linker already ad-hoc signs the
# inner arm64 binary, but without a sealed bundle (_CodeSignature/CodeResources)
# Gatekeeper reports a quarantined download as "damaged". Ad-hoc signing fixes
# that — it does NOT remove the unsigned/unnotarized first-launch prompt (use
# right-click → Open, or strip the quarantine flag with xattr).
codesign --force --deep --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP" && echo "ad-hoc signature OK"

echo "Built $APP"
echo "Run with:  open $APP    (or ./$APP/Contents/MacOS/Asterisk)"
