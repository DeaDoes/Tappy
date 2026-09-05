import AppKit
import SwiftUI

/// The catalog laid out as titled sections of tiles. The picker sheet and the
/// library differ only in column count and which badge a tile carries, so both
/// drive this one view.
struct ActionSections: View {
    var columns: Int = 2
    var tileHeight: CGFloat = 150
    var showsSubtitle = true
    var badge: (KnockAction?) -> ActionTile.Badge?
    var onSelect: (KnockAction?) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 26, pinnedViews: []) {
            ForEach(ActionCatalog.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.rawValue)
                        .font(.title3).bold()

                    LazyVGrid(columns: grid, alignment: .leading, spacing: 14) {
                        ForEach(section.cards) { card in
                            ActionTile(card: card,
                                       badge: badge(card.action),
                                       height: tileHeight,
                                       showsSubtitle: showsSubtitle) {
                                select(card)
                            }
                        }
                    }
                }
            }
        }
    }

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: max(columns, 1))
    }

    private func select(_ card: ActionCard) {
        guard let action = card.action else { onSelect(nil); return }
        guard action.needsConfiguration else { onSelect(action); return }
        if let configured = ActionConfigurator.configure(action) { onSelect(configured) }
    }
}

/// Fills in the blank on the "…" actions. Native panels rather than another
/// sheet layer: these are one question each, and a sheet on a sheet is worse.
enum ActionConfigurator {
    static func configure(_ action: KnockAction) -> KnockAction? {
        switch action {
        case .openApp:
            guard let url = chooseApp(), let id = Bundle(url: url)?.bundleIdentifier else { return nil }
            return .openApp(bundleID: id)

        case .openFile:
            guard let url = chooseFileOrFolder() else { return nil }
            return .openFile(url)

        case .openURL:
            guard let raw = ask("Open which link?", placeholder: "https://…"),
                  let url = normalizedURL(raw) else { return nil }
            return .openURL(url)

        case .runShortcut:
            guard let name = ask("Which Shortcut should this run?",
                                 placeholder: "Exact name from the Shortcuts app")
            else { return nil }
            return .runShortcut(name: name)

        case .runCommand:
            guard let command = ask("Which command should this run?", placeholder: "e.g. open -a Music")
            else { return nil }
            return .runCommand(command)

        case .showText:
            guard let text = ask("What should Tappy show on screen?", placeholder: "Back in 5") else { return nil }
            return .showText(text)

        default:
            return action
        }
    }

    // "example.com" defaults to https://; a schemeless URL opens to nothing.
    // nil for blank input so the caller can leave the slot alone.
    static func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // A leading "word:" is a scheme (https:, mailto:, file:). A schemeless
        // "host:port" reads as one too — nobody types a knock target that way.
        let hasScheme = trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression) != nil
        return URL(string: hasScheme ? trimmed : "https://\(trimmed)")
    }

    private static func chooseApp() -> URL? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func chooseFileOrFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func ask(_ question: String, placeholder: String) -> String? {
        let alert = NSAlert()
        alert.messageText = question
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
