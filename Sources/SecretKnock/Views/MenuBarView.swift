import SwiftUI

struct MenuBarView: View {
    @ObservedObject var config: AppConfig
    var micDenied = false

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
            Button("Settings...") { NotificationCenter.default.post(name: .openSettings, object: nil) }
                .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 6)
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(.red)
        }
        .frame(width: 180)
    }

    private var statusColor: Color {
        if micDenied { return .red }
        return config.mappings.isEmpty ? .orange : .green
    }

    private var statusText: String {
        if micDenied { return "No mic access — not listening" }
        if config.mappings.isEmpty { return "No knocks set" }
        return "Listening · \(config.mappings.count) knock\(config.mappings.count == 1 ? "" : "s")"
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
