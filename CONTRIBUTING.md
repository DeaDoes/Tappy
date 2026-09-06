# Contributing to Tappy

Thanks for taking a look. Tappy is small and has no dependencies — it should
build on a clean machine in under a minute.

## Getting set up

```bash
git clone https://github.com/DeaDoes/Tappy.git
cd Tappy
swift build
swift test
```

SwiftPM only. There is no Xcode project and no workspace — open the folder in
Xcode directly if you want an IDE, or use any editor.

You need macOS 13+ to build. You need **Apple silicon** to actually feel the
app work: knock detection reads a vendor HID node that doesn't exist on Intel
Macs. The test suite does not need that hardware.

## Before you open a pull request

```bash
swift test
```

All 73 tests must pass. **Nothing checks this for you** — the only workflow in
this repo is `release.yml`, which runs on version tags, not on pull requests.
If your PR breaks a test, a human has to notice.

## What we look for

**Tests.** Non-trivial logic gets a test. The suite runs in under a second
because nothing in it touches hardware, the network, or real user data — keep
it that way. If you're testing anything that reads `AppConfig`, subclass
`IsolatedConfigTestCase` rather than using `AppConfig.shared`; the real one
writes to user defaults, and a test that touches it destroys the knocks of
whoever is running the suite.

**Comments that explain why, not what.** This is the house style throughout
the codebase and the main thing a review will push back on. Not this:

```swift
// Set the window to 1 second
private static let typingSuppressionWindow: TimeInterval = 1.0
```

This:

```swift
/// A tight window leaked: hands shifting on the palm rest between words
/// produce tap-sized spikes that belong to no keystroke, and 300ms could not
/// cover the gaps. Nobody taps to launch an app mid-sentence.
private static let typingSuppressionWindow: TimeInterval = 1.0
```

If a value was tuned against real hardware, say what it was tuned against.
The physical world doesn't match the model, and the next person needs to know
which numbers are measured and which are guessed.

**No new dependencies.** `Package.swift` has zero, and the bar for the first
one is high. If a few lines of Foundation or AppKit will do, write the few
lines.

**Small diffs.** One change per pull request. A refactor bundled with a
feature is two reviews wearing one coat.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org), lowercase, in the
imperative. The prefixes already in use:

```
feat:      a new capability
fix:       a bug fix
refactor:  behaviour unchanged
docs:      documentation only
ci:        workflow and build plumbing
chore:     everything else
```

Say *why* in the body when the subject line can't carry it.

## Things that will bite you

**Signing.** `build-app.sh` signs with the first codesigning identity in your
keychain, falling back to ad-hoc with a warning. Don't change that path
casually: an ad-hoc signature pins macOS's Accessibility grant to the binary's
hash, so every update silently drops the permission while System Settings
still shows the app switched on. It looks like the app broke, not like the
signature changed.

**The DMG window layout.** If you change `Resources/dmg-bg.svg` or the icon
positions, run `./make-dmg.sh` locally once and commit the regenerated
`Resources/dmg-DS_Store`. CI replays that file rather than driving Finder, so
a layout change that isn't re-baked simply won't appear in the release.

**Accelerometer work.** It can't be tested in CI and can't be tested on Intel.
Keep the decision logic (thresholds, timing, gating) in pure functions that
tests can drive with synthetic samples, and keep the IOHID plumbing thin.

## Releases

Maintainer-only. Pushing a `v*` tag builds, signs, and publishes the DMG. You
don't need to do anything release-related in a pull request — don't bump
version numbers, they come from the tag.

## Reporting bugs

Include your macOS version, your Mac model (knock detection is
hardware-sensitive), and what you knocked versus what happened. If the app
didn't react at all, say whether the menu bar icon showed **Ready**.
