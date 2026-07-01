import SwiftUI

struct ActionPickerView: View {
    @State private var selectedType: ActionType = .app
    @State private var fileURL: URL?
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
            // Switching tabs must drop the previous tab's selection (and its
            // shown label), or "Next" stays enabled / a stale label lingers.
            .onChange(of: selectedType) { _ in
                picked = nil
                fileURL = nil
                urlString = ""
            }

            switch selectedType {
            case .app:
                Button("Choose app...") { openAppPanel() }
                if let label = pickedLabel { Text(label).foregroundStyle(.secondary) }
            case .file:
                Button("Choose file or folder...") { openFilePanel() }
                if let url = fileURL { Text(url.lastPathComponent).foregroundStyle(.secondary) }
            case .url:
                TextField("https://...", text: $urlString)
                    .onChange(of: urlString) { v in
                        picked = Self.normalizedURL(v).map(KnockAction.openURL)
                    }
            }

            Button("Next") { if let picked { onComplete(picked) } }
                .disabled(picked == nil)
        }
        .padding()
        .frame(width: 300)
    }

    private var pickedLabel: String? {
        if case .openApp(let id) = picked { return id.components(separatedBy: ".").last ?? id }
        return nil
    }

    private func openAppPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier else { return }
        picked = .openApp(bundleID: id)
    }

    // Accept "example.com" by defaulting to https:// — a schemeless URL opens
    // to nothing. Returns nil for blank input so "Next" stays disabled.
    static func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // A scheme is a leading "word:" (https:, mailto:, file:). If absent,
        // assume the web. ponytail: rare "host:port" with no scheme reads as a
        // scheme; fine — nobody types a knock target that way.
        let hasScheme = trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression) != nil
        let withScheme = hasScheme ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileURL = url
        picked = .openFile(url)
    }
}
