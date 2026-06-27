import SwiftUI

struct SettingsView: View {
    @ObservedObject var config: AppConfig
    @State private var editing: KnockMapping?
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your knocks").font(.title2).bold()
                Spacer()
                Button { editing = nil; showEditor = true } label: {
                    Label("Add knock", systemImage: "plus")
                }
            }

            if config.mappings.isEmpty {
                VStack(spacing: 6) {
                    Text("No knocks yet").font(.headline)
                    Text("Add one, then knock its rhythm on your table to trigger it.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ForEach(config.mappings) { mapping in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mapping.name).font(.headline)
                            Text("\(mapping.pattern.tapCount) taps → \(actionLabel(mapping.action))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { editing = mapping; showEditor = true }
                        Button(role: .destructive) {
                            config.mappings.removeAll { $0.id == mapping.id }
                        } label: { Image(systemName: "trash") }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Sensitivity").font(.subheadline)
                HStack {
                    Text("Gentle").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $config.sensitivity, in: 0.05...1.0)
                    Text("Hard").font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()
            Button("Quit Tappy") { NSApp.terminate(nil) }.foregroundStyle(.red)
        }
        .padding(20)
        .frame(width: 440)
        .sheet(isPresented: $showEditor) {
            KnockEditorView(config: config, existing: editing) { showEditor = false }
        }
    }

    private func actionLabel(_ action: KnockAction) -> String {
        switch action {
        case .openApp(let id): return id.components(separatedBy: ".").last ?? id
        case .openFile(let url): return url.lastPathComponent
        case .openURL(let url): return url.host ?? url.absoluteString
        }
    }
}
