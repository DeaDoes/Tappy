import SwiftUI

struct ActionPickerView: View {
    @State private var selectedType: ActionType = .app
    @State private var urlString: String = ""
    @State private var picked: KnockAction?
    let onComplete: (KnockAction) -> Void

    enum ActionType: String, CaseIterable { case app = "App", file = "File / Folder", url = "URL" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should it open?").font(.headline)

            Picker("Type", selection: $selectedType) {
                ForEach(ActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            // Drop the previous tab's selection, or "Next" stays enabled on it.
            .onChange(of: selectedType) { _ in
                picked = nil
                urlString = ""
            }

            switch selectedType {
            case .app:
                Button("Choose app...") { openAppPanel() }
            case .file:
                Button("Choose file or folder...") { openFilePanel() }
            case .url:
                TextField("https://...", text: $urlString)
                    .onChange(of: urlString) { v in
                        picked = Self.normalizedURL(v).map(KnockAction.openURL)
                    }
            }

            // Not for .url, where the field already shows it.
            if selectedType != .url, let picked {
                Text(picked.label).foregroundStyle(.secondary)
            }

            Button("Next") { if let picked { onComplete(picked) } }
                .disabled(picked == nil)
        }
        .padding()
        .frame(width: 300)
    }

    private func openAppPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier else { return }
        picked = .openApp(bundleID: id)
    }

    // "example.com" defaults to https://; a schemeless URL opens to nothing.
    // nil for blank input keeps "Next" disabled.
    static func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // A leading "word:" is a scheme (https:, mailto:, file:). A schemeless
        // "host:port" reads as one too — nobody types a knock target that way.
        let hasScheme = trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression) != nil
        let withScheme = hasScheme ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        picked = .openFile(url)
    }
}
