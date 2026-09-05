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
            MenuRow(title: "Open Tappy") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            Divider()
            MenuRow(title: "Quit", isDestructive: true) { NSApp.terminate(nil) }
        }
        .padding(.vertical, 4)
        .frame(width: 200)
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

/// A popover isn't a real NSMenu, so a plain button in it doesn't highlight on
/// hover and reads as dead text. This is the highlight, nothing more.
private struct MenuRow: View {
    let title: String
    var isDestructive = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(isHovering ? .white : (isDestructive ? Color.red : .primary))
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
