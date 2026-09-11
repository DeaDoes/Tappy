import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The first-run walkthrough, which ends by actually firing a real action from
/// a real knock.
///
/// Nothing here is simulated. The taps come from the accelerometer, the match
/// comes from `KnockDetectionEngine`, and the screenshot in the last step is
/// taken by the same `ActionLauncher` path every saved knock uses. A
/// walkthrough that mimed the result would be teaching a thing the app does not
/// do.
///
/// That is why Accessibility is requested here, in step `.permission`, rather
/// than being deferred to first use as every other action in the app is: the
/// final step *is* a first use, and it has to work.
enum WelcomeStep: Int, CaseIterable {
    case intro, tapCheck, permission, pickAction, doItForReal, menuBar

    var next: WelcomeStep? { WelcomeStep(rawValue: rawValue + 1) }

    /// Steps that cannot be left until the user has actually done something.
    /// The tap steps both need a real knock; everything else is a button.
    var needsAKnock: Bool { self == .tapCheck || self == .doItForReal }
}

/// The demo knock is always three taps, because "three taps takes a screenshot"
/// is a sentence a person can hold in their head while they tap.
let welcomeSlot: KnockSlot = .triple

/// What the last step should fire, given whether the user granted Accessibility.
///
/// Denial must not dead-end the walkthrough — it is a common answer, and
/// finishing on a broken step is the worst possible last impression. A screen
/// flash is a real action, fired by the real matcher, that needs no grant at
/// all, so the beat survives intact and only the payoff changes.
func welcomeAction(accessibilityGranted: Bool) -> KnockAction {
    accessibilityGranted ? .fullScreenshot : .screenFlash
}

@MainActor
final class WelcomeController: ObservableObject {
    @Published var step: WelcomeStep = .intro
    /// Taps seen since the current step began.
    @Published var taps = 0
    @Published var accessibilityGranted = AXIsProcessTrusted()
    /// Set once the demo knock has fired its action, so the last tap step can
    /// stop asking and start congratulating.
    @Published var demoFired = false
    /// How many taps the last attempt had, when that wasn't three. Nothing
    /// fires on a four-tap knock, so the step has to say so rather than sit
    /// there looking broken.
    @Published var missedCount: Int?

    private let config: AppConfig
    private var tapObserver: Any?
    private var pollTimer: Timer?
    private var settleWork: DispatchWorkItem?

    var isUsingTrackpad: Bool { KnockDetectionEngine.shared.isUsingTrackpadFallback }

    /// Seconds since the user last touched the keyboard. Timing only, so this
    /// needs no Input Monitoring grant — same source the detector's typing gate
    /// uses, and the reason the walkthrough can say "paused while you type"
    /// before asking for any permission at all.
    var isTyping: Bool {
        let source = CGEventSourceStateID.combinedSessionState
        return CGEventSource.secondsSinceLastEventType(source, eventType: .keyDown)
            < AccelerometerTapDetector.typingSuppressionWindowForTesting
    }

    init(config: AppConfig = .shared) {
        self.config = config

        // Steps before the finale must not fire whatever the user already has
        // saved — a knock during the intro launching someone's Spotlight would
        // be the app misbehaving during the one flow that exists to prove it
        // behaves. `.doItForReal` turns this back off deliberately.
        KnockDetectionEngine.shared.isRecordingMode = true

        tapObserver = NotificationCenter.default.addObserver(
            forName: .knockDetected, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.countTap() }
        }
    }

    deinit {
        if let tapObserver { NotificationCenter.default.removeObserver(tapObserver) }
        pollTimer?.invalidate()
    }

    private func countTap() {
        guard step.needsAKnock else { return }
        taps += 1
        missedCount = nil
        guard step == .doItForReal else { return }

        // Mirror the engine's own settling rather than declaring success on the
        // third tap. Two things go wrong otherwise: the engine waits for a quiet
        // gap before firing, so "a screenshot just landed on your Desktop" can
        // appear a second before one has — and a knock of four or five taps
        // matches no saved mapping at all, so nothing fires and the walkthrough
        // would still be congratulating them.
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.step == .doItForReal else { return }
            if self.taps == welcomeSlot.rawValue {
                self.demoFired = true
            } else {
                // Say what actually happened, then clear so they can try again.
                self.missedCount = self.taps
                self.taps = 0
            }
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + KnockDetectionEngine.settleDelay(for: config.mappings),
            execute: work
        )
    }

    func advance() {
        guard let next = step.next else { return finish() }
        settleWork?.cancel()
        taps = 0
        demoFired = false
        missedCount = nil
        step = next

        if next == .doItForReal { armTheRealThing() }
    }

    /// Saves the demo knock for real and hands detection back to the engine, so
    /// the next three taps run the ordinary path end to end: matcher, action,
    /// haptic. The mapping is left in place afterwards on purpose — the user
    /// just configured their first knock, and taking it away again at the end
    /// of the walkthrough would be a strange thing to do.
    private func armTheRealThing() {
        accessibilityGranted = AXIsProcessTrusted()
        config.assign(welcomeAction(accessibilityGranted: accessibilityGranted), to: welcomeSlot)
        KnockDetectionEngine.shared.isRecordingMode = false
    }

    /// Ask macOS for Accessibility, then watch for the answer.
    ///
    /// There is no callback for this — the user leaves to System Settings and
    /// may come back a minute later — so the status row polls instead. It stops
    /// as soon as the answer is yes.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        accessibilityGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        guard !accessibilityGranted else { return }

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.accessibilityGranted = AXIsProcessTrusted()
                if self.accessibilityGranted { timer.invalidate() }
            }
        }
    }

    func finish() {
        WelcomeWindow.close()   // its delegate calls cleanup() on the way out
    }

    /// Hand detection back and remember that the walkthrough has been seen.
    ///
    /// Must run however the window goes away — Done, Skip, or the red button —
    /// because leaving `isRecordingMode` on would make the app ignore every
    /// knock until it was relaunched. The window's delegate calls this, so the
    /// close button cannot skip it. Idempotent.
    func cleanup() {
        pollTimer?.invalidate()
        pollTimer = nil
        settleWork?.cancel()
        KnockDetectionEngine.shared.isRecordingMode = false
        config.isFirstLaunch = false

        // Leaving early means never reaching the step that says where Tappy
        // lives. Tappy has no Dock icon, so without this the window just
        // vanishes and a brand-new user is left with nothing on screen and no
        // obvious way back — the app looks like it did nothing at all.
        // Posted on the next turn of the run loop, not inside `windowWillClose`:
        // opening a window while another is mid-close hands AppKit two windows
        // fighting over key status.
        if step != .menuBar {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        }
    }
}

/// Runs `cleanup()` however the window is dismissed, including the red button,
/// which never reaches the flow's own Done and Skip paths.
@MainActor
private final class WelcomeWindowDelegate: NSObject, NSWindowDelegate {
    private let controller: WelcomeController
    init(controller: WelcomeController) { self.controller = controller }

    func windowWillClose(_ notification: Notification) {
        controller.cleanup()
        // Back to a menu bar app. `cleanup()` may reopen the main window, which
        // sets `.regular` again for itself — this only has to undo what
        // `show()` did, so the Dock icon doesn't outlive the walkthrough.
        NSApp.setActivationPolicy(.accessory)
        WelcomeWindow.forget()
    }
}

/// Hosts the walkthrough in its own window.
///
/// Deliberately not the main window: the walkthrough owns detection while it is
/// up (see `isRecordingMode`), so it has to be the only thing on screen that
/// could react to a tap.
@MainActor
enum WelcomeWindow {
    private static var window: NSWindow?
    /// The delegate is weak on NSWindow, so it has to be held here or it
    /// deallocates immediately and the close button silently stops cleaning up.
    private static var delegate: WelcomeWindowDelegate?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = WelcomeController()
        let host = NSHostingController(rootView: WelcomeView(controller: controller))
        let new = NSWindow(contentViewController: host)
        new.title = "Welcome to Tappy"
        new.styleMask = [.titled, .closable, .fullSizeContentView]
        new.titlebarAppearsTransparent = true
        new.isMovableByWindowBackground = true
        new.setContentSize(NSSize(width: 760, height: 520))
        new.isReleasedWhenClosed = false
        new.center()

        let windowDelegate = WelcomeWindowDelegate(controller: controller)
        new.delegate = windowDelegate
        delegate = windowDelegate
        window = new

        // Tappy runs as an accessory app, which has no Dock icon and no
        // Cmd-Tab entry. A walkthrough window left that way can end up behind
        // whatever else is open on a fresh Mac with no way for the user to
        // reach it again — on the one window they are meant to see first.
        // `openSettings()` does the same thing for the same reason.
        NSApp.setActivationPolicy(.regular)
        new.makeKeyAndOrderFront(nil)
        // A runloop pass after the policy switch: activating in the same tick
        // can leave the window behind other apps.
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    /// Dismiss from Done or Skip. Cleanup happens in the delegate, so every
    /// route out of the walkthrough goes through exactly one path.
    static func close() { window?.close() }

    /// Called by the delegate once the window has actually gone, so a later
    /// Replay builds a fresh controller instead of reviving a finished one.
    static func forget() {
        window = nil
        delegate = nil
    }
}
