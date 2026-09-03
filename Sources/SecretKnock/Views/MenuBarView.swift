import SwiftUI

struct MenuBarView: View {
    @ObservedObject var config: AppConfig
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
        if config.mappings.isEmpty { return .orange }
        return usingTrackpadFallback ? .yellow : .green
    }

    private var statusText: String {
        if config.mappings.isEmpty { return "No knocks set" }
        let count = "\(config.mappings.count) knock\(config.mappings.count == 1 ? "" : "s")"
        // Worth saying out loud: on a Mac without the sensor the app still
        // works, but only from trackpad clicks — tapping the case does nothing.
        return usingTrackpadFallback ? "Trackpad mode · \(count)" : "Listening · \(count)"
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
