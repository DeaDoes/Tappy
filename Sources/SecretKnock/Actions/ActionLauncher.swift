import AppKit
import Carbon.HIToolbox

enum ActionLauncher {
    @discardableResult
    static func launch(_ action: KnockAction) -> Bool {
        // A template that was saved without its target — nothing to run, and
        // "couldn't run this" beats opening whatever an empty path resolves to.
        if action.needsConfiguration { return failed(action) }

        // Asked here, at the first use of an action that needs it, rather than
        // at launch: a knock that only opens an app never sees this prompt.
        if action.needsAccessibility, !requestAccessibility() { return false }

        switch action {
        case .copy:             return post(kVK_ANSI_C, [.maskCommand])
        case .paste:            return post(kVK_ANSI_V, [.maskCommand])
        case .undo:             return post(kVK_ANSI_Z, [.maskCommand])
        case .redo:             return post(kVK_ANSI_Z, [.maskCommand, .maskShift])
        case .screenshot:       return post(kVK_ANSI_4, [.maskCommand, .maskShift])
        case .fullScreenshot:   return post(kVK_ANSI_3, [.maskCommand, .maskShift])
        case .lockScreen:       return post(kVK_ANSI_Q, [.maskCommand, .maskControl])
        case .missionControl:   return post(kVK_UpArrow, [.maskControl])
        case .nextDesktop:      return post(kVK_RightArrow, [.maskControl])
        case .previousDesktop:  return post(kVK_LeftArrow, [.maskControl])
        case .spotlight:        return post(kVK_Space, [.maskCommand])
        case .nextTab:          return post(kVK_Tab, [.maskControl])
        case .previousTab:      return post(kVK_Tab, [.maskControl, .maskShift])
        case .appSwitcher:      return post(kVK_Tab, [.maskCommand])
        case .closeTab:         return post(kVK_ANSI_W, [.maskCommand])

        case .playPause:        return postMediaKey(playPauseKey)

        case .mute:             return runScript("set volume output muted not (output muted of (get volume settings))")
        case .volumeUp:         return changeVolume(by: 10)
        case .volumeDown:       return changeVolume(by: -10)
        // pmset needs no privileges for sleepnow, so this stays clear of the
        // Automation prompt that "tell System Events to sleep" would raise.
        case .sleepMac:         return run("/usr/bin/pmset", ["sleepnow"])

        case .openApp(let bundleID):
            guard !bundleID.isEmpty,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            else { return failed(action) }
            return NSWorkspace.shared.open(url) || failed(action)

        case .openFile(let url), .openURL(let url):
            return NSWorkspace.shared.open(url) || failed(action)

        case .runShortcut(let name):
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return failed(action) }
            return run("/usr/bin/shortcuts", ["run", name])

        case .runCommand(let command):
            guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return failed(action) }
            return run("/bin/sh", ["-c", command])

        // Reported honestly rather than always true: with no attached display
        // there is nothing to draw on, and claiming success there hides a knock
        // that visibly did nothing.
        case .glitch:      return ReactionOverlay.play(.glitch)
        case .shockwave:   return ReactionOverlay.play(.shockwave)
        case .screenFlash: return ReactionOverlay.play(.flash)
        case .showText(let text):
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return failed(action) }
            return ReactionOverlay.play(.text(text))
        }
    }

    // MARK: - Keystrokes

    private static func post(_ keyCode: Int, _ flags: CGEventFlags) -> Bool {
        // A private state source, so the modifiers we set can't be merged with
        // ones the user happens to be holding down at the time.
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        else { return false }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    /// NX_KEYTYPE_PLAY from IOKit's ev_keymap.h, inlined so this file doesn't
    /// pull in the whole hidsystem header for one integer.
    private static let playPauseKey: Int = 16

    /// Media keys don't travel as keyboard events — they're NSSystemDefined
    /// with the key packed into data1, which is why they need their own path.
    private static func postMediaKey(_ key: Int) -> Bool {
        func event(down: Bool) -> CGEvent? {
            let data1 = Int((key << 16) | ((down ? 0xA : 0xB) << 8))
            return NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [],
                                      timestamp: 0, windowNumber: 0, context: nil,
                                      subtype: 8, data1: data1, data2: -1)?.cgEvent
        }
        guard let down = event(down: true), let up = event(down: false) else { return false }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Volume

    private static func changeVolume(by delta: Int) -> Bool {
        runScript("""
            set current to output volume of (get volume settings)
            set volume output volume (current + \(delta))
            """)
    }

    @discardableResult
    private static func runScript(_ source: String) -> Bool {
        // `set volume` and `get volume settings` are AppleScript's own commands,
        // not messages to another app, so this raises no Automation prompt.
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }

    // MARK: - Processes

    private static func run(_ path: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do { try process.run() } catch { return false }
        return true
    }

    // MARK: - Accessibility

    private static var hasShownSystemPrompt = false

    /// Returns true once the user has granted it.
    ///
    /// One dialog, not two. macOS puts up its own sheet the first time the app
    /// asks, so an alert of ours on top of it is just noise — ours is held back
    /// until the second refusal, when the system has stopped asking and the
    /// user needs telling where to go.
    private static func requestAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }

        if !hasShownSystemPrompt {
            hasShownSystemPrompt = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        reportOnce(
            title: "Tappy needs Accessibility access",
            message: "This knock presses keys for you, which macOS only allows with Accessibility "
                   + "access. If Tappy is already switched on there, remove it with the “−” button "
                   + "and add it again — the switch goes stale when the app is updated.",
            primaryTitle: "Open Accessibility Settings",
            primaryAction: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        )
        return false
    }

    // MARK: - Failures

    private static func failed(_ action: KnockAction) -> Bool {
        reportOnce(
            title: "Tappy couldn't run “\(action.label)”",
            message: "It may have been moved, renamed, or deleted. Open Tappy to point this knock "
                   + "somewhere else."
        )
        return false
    }

    // Main-thread only; launch() is always called from the main queue.
    private static var isReporting = false

    /// One knock can match several mappings — without the guard, one failure
    /// per match stacks a pile of modals to dismiss.
    private static func reportOnce(title: String, message: String,
                                   primaryTitle: String = "Open Tappy",
                                   primaryAction: @escaping () -> Void = {
                                       NotificationCenter.default.post(name: .openSettings, object: nil)
                                   }) {
        guard !isReporting else { return }
        isReporting = true
        // Deferred: launch() runs inside a loop, and a modal would block the rest.
        DispatchQueue.main.async {
            defer { isReporting = false }
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: primaryTitle)
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { primaryAction() }
        }
    }
}
