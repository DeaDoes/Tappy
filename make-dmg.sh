#!/bin/bash
# Packages Tappy.app into Tappy.dmg: custom wallpaper, app on the left,
# Applications on the right, drag straight across.
# Run ./build-app.sh first, then ./make-dmg.sh
set -e

APP="Tappy.app"
DMG="Tappy.dmg"
VOL="Tappy"
STAGING="dmg-staging"
BG_SVG="Resources/dmg-bg.svg"
LAYOUT="Resources/dmg-DS_Store"   # the window layout, baked by a local run
W=660; H=420          # window content size — must match dmg-bg.svg's viewBox

# GitHub's macOS runners have no logged-in GUI session, so the Finder pass below
# can't run there. Locally we drive Finder and save the resulting .DS_Store into
# the repo; in CI we just drop that file into the staging folder and skip Finder.
# Redesigned the wallpaper? Run this locally once and commit $LAYOUT.
if [ -n "$CI" ]; then USE_FINDER=0; else USE_FINDER=1; fi

[ -d "$APP" ] || { echo "Build $APP first:  ./build-app.sh"; exit 1; }
[ -f "$BG_SVG" ] || { echo "Missing $BG_SVG (run from the repo root)"; exit 1; }
[ "$USE_FINDER" = 1 ] || [ -f "$LAYOUT" ] || {
  echo "No $LAYOUT to fall back on — run this script locally once and commit it."; exit 1; }

echo "Staging..."
rm -rf "$STAGING" "$DMG" rw.dmg
mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # the drag-here target

# Two reps in one TIFF so the wallpaper stays sharp on Retina as well as 1x.
echo "Rendering wallpaper..."
VERSION=$(defaults read "$(pwd)/$APP/Contents/Info" CFBundleShortVersionString)
sed "s/__VERSION__/$VERSION/" "$BG_SVG" > "$STAGING/.background/bg.svg"
sips -s format png "$STAGING/.background/bg.svg" --out "$STAGING/.background/bg.png"    --resampleHeightWidth $H $W >/dev/null
sips -s format png "$STAGING/.background/bg.svg" --out "$STAGING/.background/bg@2x.png" --resampleHeightWidth $((H*2)) $((W*2)) >/dev/null
rm "$STAGING/.background/bg.svg"
tiffutil -cathidpicheck "$STAGING/.background/bg.png" "$STAGING/.background/bg@2x.png" \
         -out "$STAGING/.background/bg.tiff" >/dev/null
rm "$STAGING/.background/bg.png" "$STAGING/.background/bg@2x.png"

if [ "$USE_FINDER" = 0 ]; then
  echo "Applying saved layout (no Finder)..."
  cp "$LAYOUT" "$STAGING/.DS_Store"
  hdiutil create -volname "$VOL" -srcfolder "$STAGING" -ov -format UDZO \
                 -imagekey zlib-level=9 "$DMG" >/dev/null
  rm -rf "$STAGING"
  echo ""
  echo "Done → $(pwd)/$DMG"
  exit 0
fi

echo "Creating writable image..."
hdiutil create -volname "$VOL" -srcfolder "$STAGING" -ov -format UDRW -fs HFS+ rw.dmg >/dev/null
MOUNT=$(hdiutil attach rw.dmg -readwrite -noverify -noautoopen | grep -o '/Volumes/.*' | head -1)

echo "Laying out the window..."
# Finder owns .DS_Store, so the layout has to be set through Finder itself.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {240, 140, $((240 + W)), $((140 + H))}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 112
    set text size of theViewOptions to 12
    -- POSIX path, not a "disk:folder:file" spec: the colon form fails with
    -- -10006 on a freshly attached volume.
    set background picture of theViewOptions to POSIX file "$MOUNT/.background/bg.tiff"
    set position of item "$APP" to {170, 205}
    set position of item "Applications" to {490, 205}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

# Read the layout back rather than trusting that Finder took it.
osascript -e "tell application \"Finder\" to tell disk \"$VOL\" to get {position of item \"$APP\", position of item \"Applications\"}"

sync
cp "$MOUNT/.DS_Store" "$LAYOUT"   # what CI will replay
hdiutil detach "$MOUNT" >/dev/null

echo "Compressing $DMG..."
hdiutil convert rw.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf rw.dmg "$STAGING"

echo ""
echo "Done → $(pwd)/$DMG"
echo "Copy it to the website:  cp $DMG ../tappy_website/public/Tappy.dmg"
