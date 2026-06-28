#!/bin/bash
# Packages Tappy.app into Tappy.dmg with a drag-to-Applications layout.
# Run ./build-app.sh first, then ./make-dmg.sh
set -e

APP="Tappy.app"
DMG="Tappy.dmg"
STAGING="dmg-staging"

[ -d "$APP" ] || { echo "Build $APP first:  ./build-app.sh"; exit 1; }

echo "Staging..."
rm -rf "$STAGING" "$DMG"
mkdir "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # the drag-here target

echo "Creating $DMG..."
hdiutil create -volname "Tappy" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo ""
echo "Done → $(pwd)/$DMG"
echo "Upload this to Gumroad / your site."
