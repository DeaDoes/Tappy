import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var config: AppConfig
    @State private var editing: KnockMapping?
    @State private var showEditor = false
    @State private var loginItemError: String?

    // Fixed window, scrolling content. The content's height genuinely varies —
    // one row per saved knock, and a whole section that appears only in
    // accelerometer mode — and letting the window resize to fit it puts AppKit
    // in a loop: resize -> invalidate -> remeasure -> resize, until it exceeds
    // its constraint-pass limit and throws. Pinning the frame breaks that, and
    // also stops the window growing off-screen once enough knocks are saved.
    var body: some View {
        ScrollView { content.padding(20) }
            .frame(width: 460, height: 600)
            .sheet(isPresented: $showEditor) {
                KnockEditorView(config: config, existing: editing) { showEditor = false }
            }
    }

    private var content: some View {
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
                            Text("\(mapping.pattern.summary) → \(mapping.action.label)")
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

            // Knock Feel is meaningless without the sensor — on a Mac that fell
            // back to trackpad clicks there is no tap strength to tune.
            if KnockDetectionEngine.shared.isUsingTrackpadFallback {
                Text("No motion sensor on this Mac, so Tappy is counting trackpad clicks instead.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                KnockFeelView(config: config)
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
        // Full width inside the scroll view, and wrapping text reports its real
        // height instead of negotiating it — the other half of the resize loop.
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
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
