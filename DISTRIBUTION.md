# Shipping Tappy

These two steps need your own assets / Apple Developer account, so they aren't in code.

## 1. App icon

You need a 1024×1024 PNG of the icon (design it, or generate one).

In Xcode:
1. If you don't have an asset catalog yet: File → New → File → Asset Catalog → name it `Assets.xcassets`, add it to the SecretKnock target.
2. Open `Assets.xcassets` → right-click → New Image Set → rename to `AppIcon` (or add a dedicated macOS App Icon set).
3. Drag your 1024×1024 PNG in. Xcode generates the smaller sizes.
4. Target → General → App Icon → select `AppIcon`.

Menu-bar glyph (the small icon up top) already uses the SF Symbol `hand.tap`. To use a custom one, drop a template PNG into the catalog and load it in `AppDelegate.setupStatusBar()` instead of the symbol.

## 2. Code signing + notarization

Needed so other people can open Tappy without "unidentified developer" warnings. Requires a paid Apple Developer account ($99/yr).

1. **Signing identity** — in Xcode: Target → Signing & Capabilities → enable "Automatically manage signing", pick your Team. This needs a "Developer ID Application" certificate (create it in the Apple Developer portal if you don't have one).

2. **Archive** — Product → Archive (build a Release archive of the app).

3. **Export / notarize** — from the Organizer, Distribute App → Direct Distribution. Xcode uploads to Apple for notarization automatically and staples the ticket when approved.

   Or via command line after exporting `Tappy.app`:
   ```bash
   # zip it
   ditto -c -k --keepParent Tappy.app Tappy.zip
   # submit (uses an app-specific password stored in your keychain profile)
   xcrun notarytool submit Tappy.zip --keychain-profile "AC_PASSWORD" --wait
   # staple the ticket onto the app
   xcrun stapler staple Tappy.app
   ```

4. **Distribute** — zip the stapled `Tappy.app` and put it on Gumroad / your site.

Note: Tappy turns off the App Sandbox (needed for mic + launching arbitrary apps), so it can't go on the Mac App Store. Direct distribution is the path — same as Alcove.

## 3. Info.plist — required keys

SwiftPM does **not** embed `Sources/SecretKnock/Info.plist` (you'll see an "unhandled" build warning). Xcode handles it in dev, but the packaged `.app` MUST contain these keys or it breaks:

- `NSMicrophoneUsageDescription` — **without it the app crashes** the moment it asks for the mic.
- `LSUIElement = YES` — keeps it menu-bar-only (no Dock icon). The code also forces this via `setActivationPolicy(.accessory)`, so it's belt-and-suspenders.

When you make a real app target in Xcode, set its Info.plist (or build settings `INFOPLIST_KEY_NSMicrophoneUsageDescription` and `LSUIElement`) with these values.
