# Shipping Tappy

Releases are built by `.github/workflows/release.yml`, triggered by a version tag:

```bash
git tag v1.5 && git push origin v1.5
```

That runs `build-app.sh` (binary + Info.plist + signature) then `make-dmg.sh`, and
publishes `Tappy.dmg` to the public `DeaDoes/tappy-downloads` repo. Nothing is done
in Xcode; there is no Xcode project.

## Icons

Both are files in `Resources/`, not an asset catalog:

- `AppIcon.icns` — the app icon. `build-app.sh` refuses to build without it.
- `dmg-bg.svg` / `dmg-DS_Store` — the disk image wallpaper and its icon layout.
  Re-bake the `.DS_Store` locally if the wallpaper or positions change; CI replays it.

The menu-bar glyph is drawn in code, in `AppDelegate.markImage()`.

## Signing

`build-app.sh` signs with the first codesigning identity in the keychain, or whatever
`SIGN_IDENTITY` names. CI imports one from the `SIGNING_CERT_P12` / `SIGNING_CERT_PASSWORD`
secrets.

**The identity must be stable across releases.** macOS pins the Accessibility grant to the
designated requirement; an ad-hoc signature makes that a bare `cdhash`, so every update
silently drops the user's permission while System Settings still shows it enabled. If the
secret is missing, CI warns and ships ad-hoc anyway — check the run log for
`Signing identity:` before trusting a release.

The certificate is self-signed, not a Developer ID, so downloads aren't notarized:
first launch needs System Settings → Privacy & Security → Open Anyway. That's the
deliberate trade for not paying $99/yr.

Tappy also turns off the App Sandbox — raw IOHIDDevice access to the built-in
accelerometer, plus launching arbitrary apps — so the Mac App Store isn't an option
regardless.

## Info.plist

SwiftPM can't embed one, so `build-app.sh` writes the bundle's plist itself. The key that
matters:

- `LSUIElement = YES` — menu-bar only, no Dock icon. The code also forces this via
  `setActivationPolicy(.accessory)`.

No usage-description string is needed. Tap detection reads the accelerometer as an HID
input device, which triggers no TCC prompt.
