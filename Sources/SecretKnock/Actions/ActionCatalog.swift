import SwiftUI

/// How a card is painted. The mockups group by feel, not by category — a
/// screenshot is blue while the media controls beside it are purple — so the
/// tint rides on the card, not on the section.
enum ActionTint: String {
    case blue, purple, red, orange, green, gray

    /// Top-to-bottom, saturated into lighter. Cards are large, and a flat fill
    /// at this size reads as a coloured box rather than a control.
    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private var top: Color {
        switch self {
        case .blue:   return Color(red: 0.11, green: 0.42, blue: 0.90)
        case .purple: return Color(red: 0.66, green: 0.11, blue: 0.90)
        case .red:    return Color(red: 0.87, green: 0.11, blue: 0.18)
        case .orange: return Color(red: 0.85, green: 0.28, blue: 0.03)
        case .green:  return Color(red: 0.09, green: 0.75, blue: 0.24)
        case .gray:   return Color(white: 0.24)
        }
    }

    private var bottom: Color {
        switch self {
        case .blue:   return Color(red: 0.33, green: 0.60, blue: 0.88)
        case .purple: return Color(red: 0.93, green: 0.40, blue: 0.78)
        case .red:    return Color(red: 0.94, green: 0.40, blue: 0.68)
        case .orange: return Color(red: 0.89, green: 0.38, blue: 0.05)
        case .green:  return Color(red: 0.42, green: 0.87, blue: 0.51)
        case .gray:   return Color(white: 0.28)
        }
    }
}

/// One tile in the picker or the library. `action` is nil for the "None" card,
/// which clears the slot rather than assigning anything.
struct ActionCard: Identifiable, Equatable {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: ActionTint
    let action: KnockAction?

    var id: String { title }
}

enum ActionSection: String, CaseIterable, Identifiable {
    case none = "No Action"
    case essentials = "Essentials"
    case getStuffDone = "Get Stuff Done"
    case navigation = "Navigation"
    case appsAndFiles = "Apps & Files"
    case automation = "Automation"
    case reactions = "Reactions"

    var id: String { rawValue }

    var cards: [ActionCard] { ActionCatalog.cards(in: self) }
}

enum ActionCatalog {
    static let sections = ActionSection.allCases

    /// Everything the picker and the library can show, in the order they appear.
    static func cards(in section: ActionSection) -> [ActionCard] {
        switch section {
        case .none:
            return [card("None", "Do nothing for this knock.", "nosign", .gray, nil)]

        case .essentials:
            return [
                card("Copy", "Copy the current selection.", "doc.on.doc", .blue, .copy),
                card("Paste", "Paste from the clipboard.", "clipboard", .blue, .paste),
                card("Undo", "Undo the last action.", "arrow.uturn.backward", .blue, .undo),
                card("Redo", "Redo the last undone action.", "arrow.uturn.forward", .blue, .redo),
            ]

        case .getStuffDone:
            return [
                card("Full Screenshot", "Capture the whole screen straight away.", "camera.viewfinder", .blue, .fullScreenshot),
                card("Screenshot Area", "Drag to pick the part of the screen to capture.", "macwindow.badge.plus", .blue, .screenshot),
                card("Lock Screen", "Lock your Mac right away.", "lock.fill", .red, .lockScreen),
                card("Mute", "Mute or unmute your Mac instantly.", "speaker.slash.fill", .purple, .mute),
                card("Play/Pause", "Play or pause music and media.", "playpause.fill", .purple, .playPause),
                card("Volume Up", "Turn the volume up.", "speaker.wave.2.fill", .purple, .volumeUp),
                card("Volume Down", "Turn the volume down.", "speaker.wave.1.fill", .purple, .volumeDown),
                card("Sleep Mac", "Put your Mac to sleep.", "moon.fill", .purple, .sleepMac),
            ]

        case .navigation:
            return [
                card("Mission Control", "Open Mission Control.", "square.grid.3x3.fill", .blue, .missionControl),
                card("Next Desktop", "Move to the next Space.", "square.on.square", .blue, .nextDesktop),
                card("Previous Desktop", "Move back one Space.", "square.filled.on.square", .blue, .previousDesktop),
                card("Spotlight", "Open Spotlight search.", "magnifyingglass", .blue, .spotlight),
                card("Next Tab", "Switch to the next tab in your browser or editor.", "arrow.right.square", .blue, .nextTab),
                card("Previous Tab", "Switch to the previous tab.", "arrow.left.square", .blue, .previousTab),
                card("App Switcher", "Open the app switcher.", "square.grid.2x2", .blue, .appSwitcher),
                card("Close Tab", "Close the front window or tab.", "xmark.square", .blue, .closeTab),
            ]

        case .appsAndFiles:
            return [
                card("Open Finder", "Open a new Finder window.", "folder.fill", .orange, .openApp(bundleID: "com.apple.finder")),
                card("Open Terminal", "Open Terminal.", "terminal.fill", .orange, .openApp(bundleID: "com.apple.Terminal")),
                card("Open App…", "Open any app you choose.", "app.fill", .orange, .openApp(bundleID: "")),
                card("Open File…", "Open a file or folder you choose.", "doc.fill", .orange, .openFile(KnockAction.unset)),
                card("Open Link…", "Open a website.", "link", .orange, .openURL(KnockAction.unset)),
            ]

        case .automation:
            return [
                card("Run Shortcut…", "Run an Apple Shortcut by name.", "bolt.fill", .green, .runShortcut(name: "")),
                card("Run Custom Command…", "Run a custom shell command.", "terminal.fill", .green, .runCommand("")),
            ]

        case .reactions:
            return [
                card("Glitch", "Glitch your screen when you knock.", "waveform.path.ecg", .red, .glitch),
                card("Shockwave", "Send a ripple across your screen.", "dot.radiowaves.left.and.right", .red, .shockwave),
                card("Screen Flash", "Flash the screen when you knock.", "bolt.fill", .red, .screenFlash),
                card("Show Text", "Show custom text when you knock.", "textformat", .red, .showText("")),
            ]
        }
    }

    static var all: [ActionCard] { sections.flatMap(cards(in:)) }

    /// The card for a saved action. Anything the user pointed somewhere of
    /// their own — a picked app, a named Shortcut — has no catalog entry, so
    /// build one from the action itself rather than showing a blank tile.
    static func card(for action: KnockAction) -> ActionCard {
        if let match = all.first(where: { $0.action == action }) { return match }
        switch action {
        case .openApp(let bundleID):
            return card(KnockAction.appName(forBundleID: bundleID) ?? action.label,
                        "Open this app.", "app.fill", .orange, action)
        case .openFile:
            return card(action.label, "Open this file or folder.", "doc.fill", .orange, action)
        case .openURL:
            return card(action.label, "Open this link.", "link", .orange, action)
        case .runShortcut:
            return card(action.label, "Run this Apple Shortcut.", "bolt.fill", .green, action)
        case .runCommand:
            return card("Custom Command", action.label, "terminal.fill", .green, action)
        case .showText:
            return card("Show Text", "Shows “\(action.label)”.", "textformat", .red, action)
        default:
            // Every remaining case is a plain built-in and is in `all`; this is
            // only reachable if a card is dropped from the catalog.
            return card("Unknown", "This action is no longer available.", "questionmark", .gray, action)
        }
    }

    private static func card(_ title: String, _ subtitle: String, _ symbol: String,
                             _ tint: ActionTint, _ action: KnockAction?) -> ActionCard {
        ActionCard(title: title, subtitle: subtitle, symbol: symbol, tint: tint, action: action)
    }
}
