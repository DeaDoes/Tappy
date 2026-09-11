#!/bin/bash
# Builds Tappy.app from the SwiftPM executable: release binary + Info.plist +
# ad-hoc signature. Run: ./build-app.sh   →   produces ./Tappy.app
set -e

APP="Tappy.app"
BINARY="SecretKnock"   # the executableTarget name in Package.swift
ICON="Resources/AppIcon.icns"
# release.yml passes VERSION from the git tag it was triggered by. Locally,
# fall back to the newest tag reachable from HEAD rather than a hardcoded 1.0 —
# a build that always claims to be 1.0 makes the in-app version meaningless and
# makes the updater offer an "update" to every release that ever shipped.
if [ -z "$VERSION" ]; then
    TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    VERSION="${TAG#v}"
    VERSION="${VERSION:-1.0}"   # no tags yet, e.g. a fresh clone
fi
# Commit count, so two builds of the same tag are still tellable apart.
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

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
    <key>CFBundleShortVersionString</key><string>__VERSION__</string>
    <key>CFBundleVersion</key><string>__BUILD__</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Substituted after the fact: the heredoc is quoted so the plist stays readable
# as literal XML above.
sed -i '' -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" "$APP/Contents/Info.plist"

# Sign with a real identity when one exists, ad-hoc only as a fallback.
#
# This is what keeps macOS's Accessibility grant alive across updates. An
# ad-hoc signature carries no identity, so the grant is pinned to the binary's
# cdhash — every release is a different hash, so the grant silently dies while
# System Settings still shows the app switched on. A stable certificate makes
# the requirement "this bundle ID, signed by this certificate", which every
# later build still satisfies.
#
# SIGN_IDENTITY can be set explicitly (CI does); otherwise the first codesigning
# identity in the keychain is used.
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/"/{print $2; exit}')"
fi

# Hardened runtime + entitlements, matching what notarization will require.
# (No --deep: deprecated, and there's no nested code.)
if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing as: $SIGN_IDENTITY"
    # --timestamp is load-bearing, not polish. The signing certificate expires,
    # and without a secure timestamp macOS cannot tell "signed while valid" from
    # "signed after expiry" — so on the day the certificate lapses, every
    # signature made with it stops verifying. The updater runs `codesign
    # --verify` on each download, so that day it starts rejecting every update
    # for every user, silently, with no code change to blame.
    #
    # A secure timestamp pins the signing time to Apple's timestamp authority,
    # which keeps the signature valid past the certificate's own expiry. It
    # works with a self-signed identity: the timestamp covers the signature, not
    # the trust chain. It does need network at build time — that is the only
    # cost, and an offline build failing loudly beats a silent 2027 outage.
    codesign --force --options runtime --timestamp --entitlements Tappy.entitlements \
        --sign "$SIGN_IDENTITY" "$APP"
else
    echo "WARNING: no codesigning identity found — signing ad-hoc."
    echo "         Every update will break the user's Accessibility permission."
    codesign --force --options runtime --entitlements Tappy.entitlements --sign - "$APP"
fi

# Printed so a release log shows what the grant is actually pinned to: a bare
# `cdhash H"..."` means ad-hoc and a permission that dies on the next update.
echo "Designated requirement:"
# Ad-hoc prints "# designated =>", a real signature prints "designated =>".
codesign -d -r- "$APP" 2>&1 | sed -n 's/^#* *designated => /  /p'

# codesign says "Timestamp=" for a secure one and "Signed Time=" for the build
# machine's clock, which proves nothing. Checked rather than assumed: the
# difference is invisible until the certificate expires, by which point every
# release carrying it is already out there.
if [ -n "$SIGN_IDENTITY" ]; then
    if codesign -dvv "$APP" 2>&1 | grep -q '^Timestamp='; then
        echo "Secure timestamp: yes (signature outlives the certificate)"
    else
        echo "ERROR: signed without a secure timestamp — the updater will reject"
        echo "       this build once the signing certificate expires."
        exit 1
    fi
fi

echo ""
echo "Done → $(pwd)/$APP"
echo "Move it to /Applications and open it (right-click → Open the first time)."
