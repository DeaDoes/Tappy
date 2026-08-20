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
        statusItem.button?.image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "Tappy")
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.contentSize = NSSize(width: 180, height: 130)
        popover.behavior = .transient
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
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI settles the height a runloop tick late; centering now uses the stale size.
        DispatchQueue.main.async { self.settingsWindow?.center() }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        KnockDetectionEngine.shared.isRecordingMode = false
    }
}
