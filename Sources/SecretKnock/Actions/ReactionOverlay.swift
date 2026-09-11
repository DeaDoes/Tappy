import AppKit
import SwiftUI

/// Full-screen visual feedback for the "Reactions" actions. A borderless,
/// click-through window over everything else — it needs no permission because
/// it only draws, never reads the screen or presses keys.
enum ReactionOverlay {
    enum Effect: Equatable {
        case flash, glitch, shockwave, text(String)

        var duration: TimeInterval {
            switch self {
            case .flash: return 0.35
            case .glitch: return 0.5
            case .shockwave: return 0.7
            case .text: return 1.6
            }
        }
    }

    private static var window: NSWindow?

    /// False when there was no screen to draw on, so callers can report the
    /// action as having failed instead of silently claiming it ran.
    @discardableResult
    static func play(_ effect: Effect) -> Bool {
        // Replace rather than stack: a second knock during an effect should
        // restart it, not leave two transparent windows over the screen.
        window?.orderOut(nil)

        // Every display, not just the main one. On a laptop plus an external
        // monitor the main screen is wherever the menu bar is, which is
        // routinely not the screen the user is looking at — so a flash there
        // reads as the knock having done nothing.
        guard let frame = unionOfScreens else { return false }

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: ReactionView(effect: effect))
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        window = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + effect.duration) {
            // Only if it is still the current one; a newer effect owns the
            // window by then and closing it here would cut that one short.
            if window === panel { window = nil }
            panel.orderOut(nil)
        }
        return true
    }

    /// One rectangle covering every attached display, or nil when there are
    /// none — which happens for real during a display reconfiguration and in
    /// clamshell mode with the external monitor asleep.
    private static var unionOfScreens: NSRect? {
        let frames = NSScreen.screens.map(\.frame)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }
}

private struct ReactionView: View {
    let effect: ReactionOverlay.Effect
    @State private var progress: Double = 0

    // Every effect is drawn fully visible at progress 0 and animates *out*.
    // Nothing fades in: a panel that starts transparent and relies on the
    // animation to become visible shows nothing at all if the animation never
    // runs, which is exactly what a non-activating overlay panel can do.
    var body: some View {
        content
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: effect.duration)) { progress = 1 }
            }
    }

    @ViewBuilder private var content: some View {
        switch effect {
        case .flash:
            // Peaks immediately and falls away — a flash that ramps up reads as
            // the screen dimming rather than as a strike.
            Color.white.opacity(0.75 * (1 - progress))

        case .glitch:
            // Cheap RGB split: three offset bands sliding apart, screen-blended.
            ZStack {
                band(.red, offset: -40 * progress)
                band(.green, offset: 12 * progress)
                band(.blue, offset: 40 * progress)
            }
            .blendMode(.screen)
            .opacity(1 - progress)

        case .shockwave:
            GeometryReader { geo in
                let side = max(geo.size.width, geo.size.height)
                // Starts at a fifth of the screen rather than at nothing, so
                // the ring is already on screen in the very first frame.
                let radius = side * (0.2 + progress * 1.2)
                Circle()
                    .strokeBorder(Color.white.opacity(0.9 * (1 - progress)), lineWidth: 24 * (1 - progress) + 2)
                    .frame(width: radius, height: radius)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }

        case .text(let string):
            Text(string)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 48).padding(.vertical, 28)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 28))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(1 - progress)
        }
    }

    private func band(_ color: Color, offset: Double) -> some View {
        Rectangle()
            .fill(color.opacity(0.35))
            .offset(x: offset)
    }
}
