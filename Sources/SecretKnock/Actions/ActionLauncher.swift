import AppKit

enum ActionLauncher {
    static func launch(_ action: KnockAction) {
        switch action {
        case .openApp(let bundleID):
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.open(url)
            }
        case .openFile(let url):
            NSWorkspace.shared.open(url)
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        }
    }
}
