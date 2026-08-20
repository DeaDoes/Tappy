#!/bin/bash
# Builds Tappy.app from the SwiftPM executable: release binary + Info.plist +
# ad-hoc signature. Run: ./build-app.sh   →   produces ./Tappy.app
set -e

APP="Tappy.app"
BINARY="SecretKnock"   # the executableTarget name in Package.swift
ICON="Resources/AppIcon.icns"

# Checked before the rm -rf below, so a missing icon can't leave you with the
# old bundle deleted and no new one built.
[ -f "$ICON" ] || { echo "Missing $ICON (run from the repo root)"; exit 1; }

echo "Building release binary..."
swift build -c release

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BINARY" "$APP/Contents/MacOS/Tappy"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Tappy</string>
    <key>CFBundleDisplayName</key><string>Tappy</string>
    <key>CFBundleIdentifier</key><string>com.deepanjan.tappy</string>
    <key>CFBundleExecutable</key><string>Tappy</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Tappy listens for your knock through the microphone to trigger your shortcuts.</string>
</dict>
</plist>
PLIST

# Hardened runtime + mic entitlement, matching what notarization will require.
# (No --deep: deprecated, and there's no nested code.)
echo "Ad-hoc signing (hardened runtime)..."
codesign --force --options runtime --entitlements Tappy.entitlements --sign - "$APP"

echo ""
echo "Done → $(pwd)/$APP"
echo "Move it to /Applications and open it (right-click → Open the first time)."
