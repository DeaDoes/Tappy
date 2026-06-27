import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let config = AppConfig.shared
    private var engine: KnockDetectionEngine!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        killOlderInstances()
        setupStatusBar()
        engine = KnockDetectionEngine.shared
        engine.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings),
            name: .openSettings, object: nil
        )

        // First run (or no knocks yet): open Settings so the user can add one.
        if config.isFirstLaunch || config.mappings.isEmpty {
            config.isFirstLaunch = false
            openSettings()
        }
    }

    private func killOlderInstances() {
        // ponytail: match by binary path, not bundleID (nil for SwiftPM exe → would match system apps)
        let me = NSRunningApplication.current
        NSWorkspace.shared.runningApplications
            .filter { $0 != me && $0.executableURL == me.executableURL }
            .forEach { $0.forceTerminate() }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "Tappy")
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.contentSize = NSSize(width: 180, height: 130)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(config: config))
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    @objc private func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(config: config)))
            window.title = "Tappy"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // If the window closes while an editor was mid-record, make sure the
    // engine is listening again — never leave it stuck in recording mode.
    func windowWillClose(_ notification: Notification) {
        KnockDetectionEngine.shared.isRecordingMode = false
    }
}
