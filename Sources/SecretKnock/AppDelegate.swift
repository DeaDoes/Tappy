import AppKit
import SwiftUI
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let config = AppConfig.shared
    private var engine: KnockDetectionEngine!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let existing = otherRunningInstance() {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        // Set explicitly: SwiftPM doesn't embed Info.plist's LSUIElement.
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        engine = KnockDetectionEngine.shared
        startListeningWhenMicAllowed()

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings),
            name: .openSettings, object: nil
        )

        if config.isFirstLaunch || config.mappings.isEmpty {
            config.isFirstLaunch = false
            openSettings()
        }
    }

    private func startListeningWhenMicAllowed() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            engine.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.engine.start() } else { self?.showMicDeniedAlert() }
                }
            }
        default:
            showMicDeniedAlert()
        }
    }

    private func showMicDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone access needed"
        alert.informativeText = "Tappy listens for your knock through the microphone. Enable it in System Settings → Privacy & Security → Microphone, then reopen Tappy."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.setActivationPolicy(.regular)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    private func otherRunningInstance() -> NSRunningApplication? {
        // Match on binary path: bundleID is nil for a SwiftPM exe and matches system apps.
        let me = NSRunningApplication.current
        return NSWorkspace.shared.runningApplications.first {
            $0 != me && $0.executableURL == me.executableURL
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.markImage()
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.contentSize = NSSize(width: 180, height: 130)
        popover.behavior = .transient
    }

    // The website's mark — a fingertip tapping a surface — drawn from the same
    // paths as tappy_website/design-mock/logo.svg, authored on a 56pt box.
    // Template image: the menu bar tints it, so no light/dark variants needed.
    private static func markImage() -> NSImage {
        let side: CGFloat = 18, stroke: CGFloat = 3.6

        let finger = CGMutablePath()
        finger.move(to: CGPoint(x: 22, y: 19))
        finger.addCurve(to: CGPoint(x: 34, y: 19),
                        control1: CGPoint(x: 22, y: 14), control2: CGPoint(x: 34, y: 14))
        finger.addLine(to: CGPoint(x: 34, y: 36))
        finger.addCurve(to: CGPoint(x: 22, y: 36),
                        control1: CGPoint(x: 34, y: 44), control2: CGPoint(x: 22, y: 44))
        finger.closeSubpath()
        let tilt = CGAffineTransform(translationX: 28, y: 44)
            .rotated(by: -9 * .pi / 180)
            .translatedBy(x: -28, y: -44)
        let tilted = finger.copy(using: [tilt]) ?? finger

        let surface = CGMutablePath()
        surface.move(to: CGPoint(x: 12, y: 44))
        surface.addQuadCurve(to: CGPoint(x: 44, y: 44), control: CGPoint(x: 28, y: 52))

        // Fit the artwork, not the 56pt artboard — its padding is there for the
        // logo's rounded-square badge, and keeping it draws a glyph visibly
        // smaller than the system icons beside it in the menu bar.
        let ink = tilted.boundingBoxOfPath
            .union(surface.boundingBoxOfPath.insetBy(dx: -stroke / 2, dy: -stroke / 2))
        let scale = (side - 2) / max(ink.width, ink.height)

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: side / 2, y: side / 2)
            ctx.scaleBy(x: scale, y: -scale)          // SVG's y-down coordinates
            ctx.translateBy(x: -ink.midX, y: -ink.midY)
            ctx.setFillColor(.black)
            ctx.setStrokeColor(.black)

            ctx.addPath(tilted)
            ctx.fillPath()

            ctx.addPath(surface)
            ctx.setLineWidth(stroke)
            ctx.setLineCap(.round)
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tappy"
        return image
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            // Rebuilt each open: mic access can be revoked long after launch.
            let micDenied = AVCaptureDevice.authorizationStatus(for: .audio) != .authorized
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView(config: config, micDenied: micDenied)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(config: config)))
            window.title = "Tappy"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }
        // .regular while Settings is open: Dock icon, Cmd-Tab, comes to front.
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        // Both wait a runloop pass. Activating in the same tick as the policy
        // switch can leave the window behind other apps — it opened, but the
        // user sees nothing and clicks Settings again. Centering waits too,
        // because SwiftUI settles the window's height a tick after it shows.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.settingsWindow?.center()
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        KnockDetectionEngine.shared.isRecordingMode = false
    }
}
