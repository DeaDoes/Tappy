import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var config: AppConfig
    @ObservedObject private var updates = UpdateChecker.shared
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

                    Section("Updates") {
                        Toggle("Check for updates automatically", isOn: $config.automaticUpdateChecks)
                        updateRow
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

    private var updateRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tappy \(UpdateChecker.currentVersion)")
                if case .failed(let why) = updates.state {
                    Text(why).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let from = updates.justUpdatedFrom {
                    Label("Updated from Tappy \(from).", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                } else if let available = updates.availableVersion {
                    Text("Tappy \(available) is available. Tappy will restart to finish.")
                        .font(.caption).foregroundStyle(Color.accentColor)
                } else if updates.lastCheckFoundNothing {
                    Text("This is the latest version.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            switch updates.state {
            case .downloading(let fraction):
                HStack(spacing: 8) {
                    if let fraction {
                        Text("\(Int(fraction * 100))%")
                            .font(.caption).monospacedDigit()
                            .foregroundStyle(.secondary)
                        ProgressView(value: fraction).frame(width: 110)
                    } else {
                        Text("Downloading…").font(.caption).foregroundStyle(.secondary)
                        ProgressView().controlSize(.small)
                    }
                }
            case .installing:
                Text("Installing…").foregroundStyle(.secondary)
            case .idle, .failed:
                if updates.availableVersion != nil {
                    Button("Update Now") { Task { await updates.downloadAndInstall() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Check Now") { Task { await updates.check(userInitiated: true) } }
                        .disabled(updates.isChecking)
                }
            }
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
