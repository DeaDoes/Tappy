import AppKit

enum ActionLauncher {
    @discardableResult
    static func launch(_ action: KnockAction) -> Bool {
        let opened: Bool
        switch action {
        case .openApp(let bundleID):
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

    // Main-thread only; launch() is always called from the main queue.
    private static var isReporting = false

    private static func reportMissing(_ action: KnockAction) {
        // One knock can match several mappings — without the guard, one failure
        // per match stacks a pile of modals to dismiss.
        guard !isReporting else { return }
        isReporting = true
        // Deferred: launch() runs inside a loop, and a modal would block the rest.
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
