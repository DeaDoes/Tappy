# Tappy

Knock on your MacBook. Something happens.

Tappy is a menu-bar app that turns physical taps on your Mac's body into
actions. Single, double and triple knocks each map to whatever you want —
screenshot, lock screen, mute, next Space, launch an app, run a Shortcut.

**[trytappy.app](https://trytappy.app)** · macOS 13 or later · Apple silicon

## How it reads a knock

There is no microphone involved. Tappy reads the **built-in accelerometer** as
a raw `IOHIDDevice` — a vendor node at usage page `0xFF00`, usage `3`, present
on Apple silicon Macs — and looks for the spike a knuckle makes. No recording,
no mic permission prompt, nothing to leak.

Typing produces identical spikes, and amplitude can't tell them apart. So the
rule is timing: a tap only counts once the keyboard has been quiet for a full
second. Deliberately generous — hands shifting on the palm rest between words
make tap-sized spikes belonging to no keystroke, and nobody knocks to launch
an app mid-sentence.

## What a knock can do

| | |
|---|---|
| **Essentials** | copy, paste, undo, redo |
| **Get Stuff Done** | screenshot (full or area), lock screen, sleep, mute, volume |
| **Navigation** | Mission Control, Spaces, Spotlight, tab switching, app switcher |
| **Automation** | open an app, file or URL; run a Shortcut; run a shell command |
| **Reactions** | on-screen glitch, shockwave, flash, custom text |

Beyond the three fixed slots you can record a custom rhythm — knock it once,
Tappy learns the timing, and matches it later within your chosen tolerance.

## Install

Download the DMG from [trytappy.app](https://trytappy.app) and drag it to
Applications.

Tappy is signed but **not notarized** — that needs a paid Apple Developer
account. So on first launch macOS will refuse to open it. Go to **System
Settings → Privacy & Security**, scroll down, and click **Open Anyway**. Once
only.

It then asks for **Accessibility** access the first time you use an action
that needs it, not at launch.

Updates are checked once a day and install in place. Tappy verifies the
download was signed by the same identity as the running copy before it
replaces anything.

## Build from source

```bash
swift build -c release     # binary only
swift test                 # 73 tests, no network or hardware needed
./build-app.sh             # assembles Tappy.app with Info.plist + signature
./make-dmg.sh              # packages Tappy.dmg with the install window
```

SwiftPM only — there's no Xcode project. `build-app.sh` writes the bundle's
`Info.plist` itself because SwiftPM can't embed one.

Signing uses the first codesigning identity in your keychain, or whatever
`SIGN_IDENTITY` names. Without one it falls back to ad-hoc and warns you: an
ad-hoc signature pins macOS's Accessibility grant to the binary's hash, so
every rebuild silently drops the permission.

## Why it can't be on the App Store

Reading the accelerometer as a raw HID device is incompatible with the App
Sandbox, and Tappy also launches arbitrary apps. Direct distribution is the
only path.

## License

MIT — see [LICENSE](LICENSE).
