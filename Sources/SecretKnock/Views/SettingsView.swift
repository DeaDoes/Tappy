import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var config: AppConfig
    @State private var loginItemError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings").font(.largeTitle).bold()
                    Text("How Tappy behaves in the background.")
                        .foregroundStyle(.secondary)
                }

                Form {
                    Section {
                        Toggle("Launch at login", isOn: launchAtLogin)
                        if let loginItemError {
                            Text(loginItemError).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Section {
                        Toggle("Allow shared rhythm", isOn: $config.allowSharedRhythm)
                        Text("Let one rhythm open several apps. Off: each rhythm can be used by only one knock.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section {
                        Toggle("Context-aware gestures", isOn: $config.contextAwareGestures)
                        Text("Use different knock actions when a specific app is active.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 560)

                Button("Quit Tappy") { NSApp.terminate(nil) }
                    .foregroundStyle(.red)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
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
