import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var config: AppConfig
    @ObservedObject private var meter = AudioMeter.shared
    @State private var editing: KnockMapping?
    @State private var showEditor = false
    @State private var loginItemError: String?

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
                            Text("\(mapping.pattern.tapCount) taps → \(mapping.action.label)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Test") { ActionLauncher.launch(mapping.action) }
                            .help("Run this knock's action now")
                        Button("Edit") { editing = mapping; showEditor = true }
                        Button(role: .destructive) {
                            config.mappings.removeAll { $0.id == mapping.id }
                        } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete \(mapping.name)")
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Sensitivity").font(.subheadline)
                LevelMeterView(level: meter.level, threshold: config.sensitivity)
                HStack {
                    Text("Gentle").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $config.sensitivity, in: 0.05...1.0)
                    Text("Hard").font(.caption).foregroundStyle(.secondary)
                }
                Text("Knock now — the bar should jump past the marker. Keep ambient noise below it.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Toggle("Allow shared rhythm", isOn: $config.allowSharedRhythm)
                Text("Let one rhythm open several apps. Off: each rhythm can be used by only one knock.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Toggle("Launch at login", isOn: launchAtLogin)
                if let loginItemError {
                    Text(loginItemError).font(.caption2).foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("Quit Tappy") { NSApp.terminate(nil) }.foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 460)
        .sheet(isPresented: $showEditor) {
            KnockEditorView(config: config, existing: editing) { showEditor = false }
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { on in
                do {
                    if on { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                    loginItemError = nil
                } catch {
                    // Registering needs a signed .app in /Applications; without a
                    // message the toggle just springs back and reads as broken.
                    loginItemError = "Couldn't change this: \(error.localizedDescription)"
                }
            }
        )
    }
}

struct LevelMeterView: View {
    let level: Double
    let threshold: Double
    private let maxScale = 1.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fill = min(level / maxScale, 1.0) * w
            let mark = min(threshold / maxScale, 1.0) * w
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 4)
                    .fill(level > threshold ? Color.green : Color.accentColor)
                    .frame(width: fill)
                Rectangle().fill(Color.primary.opacity(0.6))
                    .frame(width: 2).offset(x: mark)
            }
        }
        .frame(height: 10)
    }
}
