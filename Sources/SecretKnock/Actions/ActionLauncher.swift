import AppKit

enum ActionLauncher {
    @discardableResult
    static func launch(_ action: KnockAction) -> Bool {
        let opened: Bool
        switch action {
        case .openApp(let bundleID):
            // The app may have been uninstalled since this knock was saved.
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                reportMissing(action)
                return false
            }
            opened = NSWorkspace.shared.open(url)
        case .openFile(let url), .openURL(let url):
            opened = NSWorkspace.shared.open(url)
        }
        if !opened { reportMissing(action) }
        return opened
    }

    // ponytail: main-thread only — launch() is always called from the main queue
    // (the detection engine's settle timer, or a Settings button).
    private static var isReporting = false

    // A knock that opens nothing is indistinguishable from Tappy being broken,
    // so name the missing target instead of failing silently.
    private static func reportMissing(_ action: KnockAction) {
        // One knock can match several mappings, and a user whose target is gone
        // knocks again. Without this guard every failure stacks its own modal
        // and they have to dismiss a pile of them.
        guard !isReporting else { return }
        isReporting = true
        // Deferred: launch() runs inside a loop over matches, and a modal here
        // would block the remaining ones (and the haptic) until dismissed.
        DispatchQueue.main.async {
            defer { isReporting = false }
            let alert = NSAlert()
            alert.messageText = "Tappy couldn't open “\(action.label)”"
            alert.informativeText = "It may have been moved, renamed, or deleted. Open Settings to point this knock somewhere else."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        }
    }
}
