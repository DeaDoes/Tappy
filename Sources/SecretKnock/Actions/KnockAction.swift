import AppKit

/// What a knock does. Presentation (title, icon, colour) lives in
/// `ActionCatalog` — this enum is only the behaviour, so the launcher and the
/// UI can evolve apart.
///
/// The three original cases keep their names on purpose: Codable's synthesized
/// enum coding keys them by case name, so knocks saved before the action
/// catalog existed still decode.
enum KnockAction: Codable, Equatable, Hashable {
    // Editing — posted as keystrokes, so they hit the frontmost app.
    case copy, paste, undo, redo

    // System. `screenshot` is the drag-a-region one and keeps its name so
    // knocks saved against it still decode; `fullScreenshot` grabs everything.
    case screenshot, fullScreenshot, lockScreen, sleepMac
    case mute, playPause, volumeUp, volumeDown

    // Navigation
    case missionControl, nextDesktop, previousDesktop, spotlight
    case nextTab, previousTab, appSwitcher, closeTab

    // Targets
    case openApp(bundleID: String)
    case openFile(URL)
    case openURL(URL)

    // Automation
    case runShortcut(name: String)
    case runCommand(String)

    // Reactions — screen effects, no permission needed.
    case glitch, shockwave, screenFlash
    case showText(String)

    /// Short human name. The catalog has richer titles for the built-ins; this
    /// is the fallback for anything the user pointed somewhere custom.
    var label: String {
        switch self {
        // Deliberately string-only: the installed app's real name is a display
        // concern, so the lookup lives in ActionCatalog where it can't make
        // this value depend on what happens to be installed.
        case .openApp(let id): return id.components(separatedBy: ".").last ?? id
        case .openFile(let url): return url.lastPathComponent
        case .openURL(let url): return url.host ?? url.absoluteString
        case .runShortcut(let name): return name.isEmpty ? "Run Shortcut" : name
        case .runCommand(let cmd): return cmd.isEmpty ? "Run Command" : cmd
        case .showText(let text): return text.isEmpty ? "Show Text" : text
        default: return ActionCatalog.card(for: self).title
        }
    }

    /// Posting keystrokes into another app is what needs Accessibility. Opening
    /// things, changing volume and drawing overlays do not.
    var needsAccessibility: Bool {
        switch self {
        case .copy, .paste, .undo, .redo,
             .screenshot, .fullScreenshot, .lockScreen,
             .playPause,
             .missionControl, .nextDesktop, .previousDesktop, .spotlight,
             .nextTab, .previousTab, .appSwitcher, .closeTab:
            return true
        default:
            return false
        }
    }

    /// Stands in for "no file or link chosen yet" in the catalog's template
    /// cards. An empty string is not usable here: `URL(fileURLWithPath: "")`
    /// silently resolves to the working directory, which would make an
    /// unconfigured card look configured and open that folder.
    static let unset = URL(string: "tappy-unset:")!

    /// True while a parameterised action still has nothing to act on, so the
    /// picker knows to ask before saving it.
    var needsConfiguration: Bool {
        switch self {
        case .openApp(let id): return id.isEmpty
        case .openFile(let url), .openURL(let url): return url.scheme == Self.unset.scheme
        case .runShortcut(let name): return name.trimmingCharacters(in: .whitespaces).isEmpty
        case .runCommand(let cmd): return cmd.trimmingCharacters(in: .whitespaces).isEmpty
        case .showText(let text): return text.trimmingCharacters(in: .whitespaces).isEmpty
        default: return false
        }
    }

    static func appName(forBundleID id: String) -> String? {
        guard !id.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }
}
