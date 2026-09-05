import SwiftUI

struct MenuBarView: View {
    @ObservedObject var config: AppConfig
    @ObservedObject private var updates = UpdateChecker.shared
    var usingTrackpadFallback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if let version = updates.availableVersion {
                switch updates.state {
                case .downloading(let fraction):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloading Tappy \(version)…").font(.caption)
                        if let fraction {
                            ProgressView(value: fraction)
                        } else {
                            ProgressView().progressViewStyle(.linear)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                case .installing:
                    Text("Installing Tappy \(version)…").font(.caption)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                case .idle, .failed:
                    MenuRow(title: "Update to Tappy \(version)", isProminent: true) {
                        Task { await updates.downloadAndInstall() }
                    }
                }
                Divider()
            }

            MenuRow(title: "Open Tappy") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            Divider()
            MenuRow(title: "Quit", isDestructive: true) { NSApp.terminate(nil) }
        }
        .padding(.vertical, 4)
        .frame(width: 220)
        // Opening the menu is a good moment for a fresh answer, and it costs
        // one request at most once a day thanks to the checker's own guard.
        .task { await updates.check() }
    }

    private var statusColor: Color {
        if config.mappings.isEmpty { return .orange }
        return usingTrackpadFallback ? .yellow : .green
    }

    private var statusText: String {
        if config.mappings.isEmpty { return "No knocks set" }
        let count = "\(config.mappings.count) knock\(config.mappings.count == 1 ? "" : "s")"
        // "Ready", not "Listening": nothing is heard. Tappy feels the knock in
        // the case through the motion sensor, and saying otherwise implies a
        // microphone it no longer uses.
        //
        // Worth saying out loud: on a Mac without the sensor the app still
        // works, but only from trackpad clicks — tapping the case does nothing.
        return usingTrackpadFallback ? "Trackpad mode · \(count)" : "Ready · \(count)"
    }
}

/// A popover isn't a real NSMenu, so a plain button in it doesn't highlight on
/// hover and reads as dead text. This is the highlight, nothing more.
private struct MenuRow: View {
    let title: String
    var isDestructive = false
    var isProminent = false
    let action: () -> Void

    @State private var isHovering = false

    private var tint: Color {
        if isHovering { return .white }
        if isDestructive { return .red }
        return isProminent ? .accentColor : .primary
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isProminent ? .medium : .regular)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isHovering ? Color.accentColor : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .onHover { isHovering = $0 }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
