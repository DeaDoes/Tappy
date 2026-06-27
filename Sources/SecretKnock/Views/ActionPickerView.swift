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
                        if let url = URL(string: v) { picked = .openURL(url) }
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
        // ponytail: accessory apps need .regular policy for panels to grab focus; restore after
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        let response = panel.runModal()
        NSApp.setActivationPolicy(.accessory)
        guard response == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier else { return }
        picked = .openApp(bundleID: id)
    }

    private func openFilePanel() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        let response = panel.runModal()
        NSApp.setActivationPolicy(.accessory)
        guard response == .OK, let url = panel.url else { return }
        fileURL = url
        picked = .openFile(url)
    }
}
