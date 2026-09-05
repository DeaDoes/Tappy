import AppKit
import SwiftUI
import os

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let config = AppConfig.shared
    private var engine: KnockDetectionEngine!
    private var settingsWindow: NSWindow?
    private var clickMonitor: Any?

    /// Sent by a second copy of Tappy to the one already running, asking it to
    /// show its window before the second copy quits.
    private static let openWindowNotification = Notification.Name("com.deepanjan.tappy.openWindow")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.logUncaughtExceptions()
        if let existing = otherRunningInstance() {
            existing.activate(options: [])
            // Activating alone shows nothing — the running copy is a menu bar
            // app and may have no window. Ask it to open one before quitting,
            // delivered immediately because this process is about to go away.
            DistributedNotificationCenter.default().postNotificationName(
                Self.openWindowNotification, object: nil, userInfo: nil, deliverImmediately: true
            )
            NSApp.terminate(nil)
            return
        }
        // Set explicitly: SwiftPM doesn't embed Info.plist's LSUIElement.
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        engine = KnockDetectionEngine.shared
        engine.start()
        UpdateChecker.shared.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings),
            name: .openSettings, object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(openSettings),
            name: Self.openWindowNotification, object: nil
        )

        // An update relaunches the app with no window, which from the outside
        // looks exactly like Tappy having crashed. Show the window so the
        // Settings page can say what happened.
        let justUpdated = UpdateChecker.shared.consumeUpdateResult()

        if justUpdated || config.isFirstLaunch || config.mappings.isEmpty {
            config.isFirstLaunch = false
            openSettings()
        }
    }

    // AppKit swallows the reason and stops in _crashOnException, which tells you
    // nothing without a debugger attached. Write it somewhere `log stream` sees.
    private static func logUncaughtExceptions() {
        NSSetUncaughtExceptionHandler { exception in
            let log = Logger(subsystem: "com.deepanjan.tappy", category: "crash")
            log.fault("""
                uncaught \(exception.name.rawValue, privacy: .public): \
                \(exception.reason ?? "no reason", privacy: .public)
                """)
            for frame in exception.callStackSymbols.prefix(25) {
                log.fault("  \(frame, privacy: .public)")
            }
        }
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
        popover.contentSize = NSSize(width: 200, height: 130)
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
        if popover.isShown { closePopover() }
        else {
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView(config: config,
                                      usingTrackpadFallback: engine.isUsingTrackpadFallback)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // `.transient` is supposed to do this, but it only closes on events
            // this app receives — and a menu bar app is usually not the active
            // one, so a click in another window left the popover hanging there.
            // Watching clicks that go elsewhere is what makes it behave like a
            // real menu.
            clickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    @objc private func openSettings() {
        closePopover()
        let isNewWindow = settingsWindow == nil
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: MainWindowView(config: config)))
            window.title = "Tappy"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 1040, height: 700))
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
        // because SwiftUI settles the window's height a tick after it shows —
        // and only on the first open, or it yanks a window the user has moved.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if isNewWindow { self.settingsWindow?.center() }
        }
    }

    /// Opening the app again when it is already running — a double-click in
    /// Finder, its Dock icon, `open Tappy.app`. macOS delivers this instead of
    /// launching a second copy, and without handling it a menu bar app simply
    /// does nothing, which reads as "the app won't open".
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openSettings() }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        KnockDetectionEngine.shared.isRecordingMode = false
    }
}
