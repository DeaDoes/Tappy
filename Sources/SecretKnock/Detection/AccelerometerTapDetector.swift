import AppKit
import IOKit.hid
import os

/// Reads the built-in accelerometer over IOKit HID and calls `onTap` once per
/// physical tap on the chassis.
///
/// The vendor node at usage page 0xFF00 / usage 3 does **not** expose per-axis
/// HID elements. `IOHIDDeviceRegisterInputValueCallback` never fires on it — the
/// only element is one opaque 856-bit blob. What it does deliver is a packed
/// 22-byte input report at ~795 Hz, carrying three int16 axis lanes at byte
/// offsets 6, 10 and 14. Measured on Mac16,12 (M4); the layout is undocumented,
/// so nothing here assumes absolute units — detection runs off per-sample
/// deltas, and the idle noise floor is measured at launch.
///
/// Which lane is X, Y or Z is deliberately never established: a tap is a sudden
/// change in *any* direction, so the jerk magnitude across all three lanes is
/// the whole signal. Axis identity would only matter for locating a tap, which
/// a single centre-mounted sensor cannot do reliably.
final class AccelerometerTapDetector {
    private static let log = Logger(subsystem: "com.deepanjan.tappy", category: "sensor")

    // Byte offsets of the three int16 axis lanes within the 22-byte report.
    private static let axisOffsets = [6, 10, 14]
    private static let reportLength = 22

    /// How long to watch an idle machine before deciding what "quiet" looks like.
    private static let calibrationWindow: TimeInterval = 1.5
    /// No matching device within this long means the sensor isn't there.
    private static let matchTimeout: TimeInterval = 2.5
    /// A hit rings for a few ms; ignore everything inside this after one fires.
    private static let cooldown: TimeInterval = 0.12
    /// How often to confirm the stream is still running. Measured idle rate is
    /// ~795 Hz and flat, so any tick with zero new reports is a real stall, not
    /// a quiet moment — nothing the user does can make the sensor go silent.
    private static let watchdogInterval: TimeInterval = 5
    /// While you are typing, Tappy stays out of the way entirely.
    ///
    /// This is the *only* thing separating typing from tapping — amplitude
    /// cannot (see `floor`) — so it is deliberately generous. A tight
    /// window leaked: hands shifting on the palm rest between words produce
    /// tap-sized spikes that belong to no keystroke, and 300ms could not cover
    /// the gaps. A full second means a typing session is quiet throughout, and
    /// costs only a brief pause before a tap counts. Nobody taps to launch an
    /// app mid-sentence.
    private static let typingSuppressionWindow: TimeInterval = 1.0
    static var typingSuppressionWindowForTesting: TimeInterval { typingSuppressionWindow }

    /// The whole typing guarantee, in one testable place: a tap is only ever
    /// accepted when the keyboard has been quiet for longer than the window.
    ///
    /// Pure and static on purpose — this is the rule the app promises users, so
    /// it is asserted directly in tests rather than inferred from behaviour.
    static func acceptsTap(secondsSinceTyping: Double) -> Bool {
        secondsSinceTyping > typingSuppressionWindow
    }

    private var manager: IOHIDManager?
    /// Two nodes match 0xFF00/3 on Apple Silicon: the sensor, which streams
    /// 22-byte reports, and the internal keyboard/trackpad, which streams
    /// 108-byte ones. `MaxInputReportSize` is what tells them apart — see
    /// `open(_:)`. Only the sensor is ever opened, so this holds one device.
    private var devices: [IOHIDDevice] = []
    /// Must outlive the callback registration, so it can't be a local array.
    private let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)

    private var onTap: (() -> Void)?
    private var lastAxes: (Double, Double, Double)?
    private var lastTapAt: TimeInterval = 0

    private var calibrationDeadline: TimeInterval = 0
    /// ~1200 jerk samples at 795 Hz, discarded once the percentile is taken.
    private var calibrationSamples: [Double] = []
    private var noiseCeiling: Double = 0
    private var isCalibrated = false
    private var reportCount = 0
    /// `reportCount` as of the last watchdog tick, to spot a stream that stopped.
    private var lastWatchdogCount = 0
    /// True once this Mac has proven it has a working sensor.
    ///
    /// Separates the two reasons for silence, which need opposite responses.
    /// Before it: the hardware may simply not be there, and the trackpad is the
    /// only thing left. After it: the hardware is known good, so silence is a
    /// stall to keep reopening through — dropping to the trackpad there would
    /// turn every mouse click in every app into a tap.
    private var sensorEverDelivered = false

    /// True once the HID node failed to appear and we fell back to the trackpad.
    private(set) var isUsingTrackpadFallback = false
    private var trackpadMonitor: Any?

    /// Bumped on every start so a watchdog scheduled by an earlier session can't
    /// fire against the current one and wrongly declare the sensor absent.
    private var generation = 0

    deinit { reportBuffer.deallocate() }

    // MARK: - lifecycle

    func start(onTap: @escaping () -> Void) {
        self.onTap = onTap

        generation += 1
        let session = generation

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr

        IOHIDManagerSetDeviceMatching(mgr, [
            kIOHIDDeviceUsagePageKey as String: 0xFF00,
            kIOHIDDeviceUsageKey as String: 3,
        ] as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(mgr, { context, _, _, device in
            guard let context else { return }
            Unmanaged<AccelerometerTapDetector>.fromOpaque(context)
                .takeUnretainedValue()
                .open(device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            Self.log.error("IOKit init failed (0x\(String(result, radix: 16), privacy: .public))")
            enableTrackpadFallback(reason: "IOHIDManagerOpen failed")
            return
        }
        Self.log.info("IOKit init ok — matching usagePage=0xFF00 usage=3")

        // The manager stays silent on hardware without the sensor: no error, no
        // callback. Only a timeout distinguishes "not here" from "not yet".
        // Both checks below decide this Mac has no usable sensor, so neither may
        // run on a reopen — a restart that takes a moment to deliver is not a
        // Mac without an accelerometer. See `sensorEverDelivered`.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.matchTimeout) { [weak self] in
            guard let self, self.generation == session, !self.sensorEverDelivered,
                  self.devices.isEmpty else { return }
            self.enableTrackpadFallback(reason: "no matching HID device within \(Self.matchTimeout)s")
        }

        // A node can match and open cleanly and still deliver nothing. Without
        // this the app looks healthy in the log and silently never detects a tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.matchTimeout + Self.calibrationWindow) { [weak self] in
            guard let self, self.generation == session, !self.sensorEverDelivered,
                  self.reportCount == 0 else { return }
            self.enableTrackpadFallback(reason: "device opened but delivered no reports")
        }

        lastWatchdogCount = 0
        scheduleWatchdog(session: session)
    }

    /// A stream that was running can stop with no error and no callback — the
    /// node stays open and simply goes quiet, and the app is then deaf for the
    /// rest of the session with nothing in the log to say so. The startup checks
    /// above can't catch that: they run once, before the stall.
    private func scheduleWatchdog(session: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.watchdogInterval) { [weak self] in
            guard let self, self.generation == session, !self.isUsingTrackpadFallback else { return }
            defer { self.scheduleWatchdog(session: session) }

            // A reopen resets the count to zero, so a reopen that delivered
            // nothing reads as stalled here and gets reopened again. That is the
            // intent: this only ever runs on a Mac whose sensor has worked, so
            // retrying is the only way back — there is no trackpad to fall to.
            guard Self.hasStalled(reportCount: self.reportCount, since: self.lastWatchdogCount) else {
                self.lastWatchdogCount = self.reportCount
                return
            }
            Self.log.notice("sensor went silent after \(self.reportCount) reports — reopening")
            self.restart()
        }
    }

    /// The stall rule, kept pure so it can be asserted directly: the sensor free-runs,
    /// so a whole interval with no new report means the stream stopped.
    static func hasStalled(reportCount: Int, since previous: Int) -> Bool {
        reportCount == previous
    }

    /// Only ever a `MaxInputReportSize` of 22 — see `open(_:)`.
    static func isSensor(reportSize: Int) -> Bool { reportSize == reportLength }

    /// Close everything and open it again from scratch, calibration included:
    /// whatever the sensor's state is after a stall, it isn't the one the old
    /// noise floor was measured in.
    private func restart() {
        for device in devices {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        devices = []
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil

        lastAxes = nil
        calibrationSamples = []
        isCalibrated = false
        reportCount = 0

        // Bumps `generation`, so the watchdog chain that called this retires and
        // a fresh one takes over with the new session.
        if let onTap { start(onTap: onTap) }
    }

    private func open(_ device: IOHIDDevice) {
        // The second node matching 0xFF00/3 is the Apple Internal Keyboard /
        // Trackpad, which streams 108-byte reports of its own. Its report size
        // is the only thing that separates the two, so filter on that and never
        // open it: it costs a needless Input Monitoring grant, and its traffic
        // is high-rate noise this callback would drop 800 times a second.
        let reportSize = (IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int) ?? 0
        guard Self.isSensor(reportSize: reportSize) else {
            Self.log.info("skipping a matching device with a \(reportSize)-byte report")
            return
        }
        Self.log.info("matched accelerometer device")

        let status = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            Self.log.error("IOHIDDeviceOpen failed (0x\(String(status, radix: 16), privacy: .public))")
            return
        }
        Self.log.info("IOHIDDeviceOpen success")

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, 256, { context, _, _, _, _, report, length in
            guard let context else { return }
            Unmanaged<AccelerometerTapDetector>.fromOpaque(context)
                .takeUnretainedValue()
                .handle(report: report, length: length)
        }, context)

        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        devices.append(device)
        Self.log.info("device \(self.devices.count) scheduled with run loop; input report callback registered")
    }

    // MARK: - decode + detect

    private func handle(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length == Self.reportLength else { return }
        if reportCount == 0 {
            // Anchored to the first report, not to start(): a slow device match
            // would otherwise eat most of the window and calibrate off nothing.
            calibrationDeadline = Date.timeIntervalSinceReferenceDate + Self.calibrationWindow
            sensorEverDelivered = true
            Self.log.info("first report received; calibrating noise floor for \(Self.calibrationWindow)s")
        }
        reportCount += 1

        func lane(_ offset: Int) -> Double {
            Double(Int16(bitPattern: UInt16(report[offset]) | UInt16(report[offset + 1]) << 8))
        }
        let axes = (lane(Self.axisOffsets[0]), lane(Self.axisOffsets[1]), lane(Self.axisOffsets[2]))
        defer { lastAxes = axes }
        guard let previous = lastAxes else { return }

        let dx = axes.0 - previous.0
        let dy = axes.1 - previous.1
        let dz = axes.2 - previous.2
        let jerk = (dx * dx + dy * dy + dz * dz).squareRoot()

        let now = Date.timeIntervalSinceReferenceDate

        // Calibration. Idle noise here is bursty rather than Gaussian (its sd
        // exceeds its mean), so mean+Nσ is a poor anchor — but so is the plain
        // maximum, which a single bump or an early test tap would dominate.
        // The 99th percentile ignores those few outliers while still tracking a
        // genuinely noisy machine.
        guard isCalibrated else {
            calibrationSamples.append(jerk)
            if now >= calibrationDeadline {
                let sorted = calibrationSamples.sorted()
                noiseCeiling = sorted[min(Int(Double(sorted.count) * 0.99), sorted.count - 1)]
                calibrationSamples = []
                isCalibrated = true
                Self.log.info("""
                    calibrated: noiseCeiling=\(self.noiseCeiling, format: .fixed(precision: 1)) \
                    threshold=\(self.threshold, format: .fixed(precision: 1))
                    """)
            }
            return
        }

        // As a multiple of the trigger: 1.0 is exactly threshold, whatever the
        // preset or this Mac's raw scale. Lets the meter be unit-free.
        TapMeter.shared.report(jerk / threshold)

        guard jerk > threshold else { return }
        guard now - lastTapAt > Self.cooldown else { return }

        // Checked only for candidate taps, not every one of the ~795 reports a
        // second — these are cheap but not free.
        let sinceTyping = secondsSinceTyping
        guard Self.acceptsTap(secondsSinceTyping: sinceTyping) else {
            Self.log.debug("gate: suppressed jerk=\(jerk, format: .fixed(precision: 0)) — \((sinceTyping * 1000), format: .fixed(precision: 0))ms after a key event")
            return
        }
        lastTapAt = now

        // sinceTyping is logged on accepted taps too, so a real session can be
        // audited afterwards: every accepted tap must show a gap above the
        // window, and any that doesn't is a gate bug with evidence attached.
        Self.log.debug("""
            tap: jerk=\(jerk, format: .fixed(precision: 0)) threshold=\(self.threshold, format: .fixed(precision: 0)) \
            sinceTyping=\((sinceTyping * 1000), format: .fixed(precision: 0))ms
            """)
        onTap?()
    }

    /// The user's chosen strength, raised only if this machine's idle noise is
    /// loud enough to trigger itself.
    ///
    /// The noise term is capped: an uncapped one turns a single bump during the
    /// 1.5s calibration into a permanently deaf app, and tapping the case right
    /// after launch to see whether it works is the most natural thing a user can
    /// do. Worst case now is "you must tap hard", never "nothing works".
    private var threshold: Double {
        Self.threshold(sensitivity: AppConfig.shared.sensitivity, noiseCeiling: noiseCeiling)
    }

    static func threshold(sensitivity: Double, noiseCeiling: Double) -> Double {
        max(threshold(for: sensitivity), min(noiseCeiling * 3, ceiling))
    }

    /// The slider spans 800...2800.
    ///
    /// Be clear about what this control does and doesn't do: it sets **how
    /// firmly you have to tap**, not whether typing gets through. Measured from
    /// real working typing on this machine, keystroke spikes run median 1181,
    /// p95 2144, max 3807 — while deliberate taps run median 1128, max 2824.
    /// The two distributions sit on top of each other, so no position on this
    /// slider separates them.
    ///
    /// What separates them is time, not size: a keystroke spike lands next to a
    /// key event and a deliberate tap does not. That is `typingSuppressionWindow`
    /// above, and it is what actually keeps typing out — at every slider
    /// position. The 800 floor only keeps the gentlest setting from firing on
    /// ordinary desk noise.
    static let floor: Double = 800
    static let ceiling: Double = 2800

    static func threshold(for sensitivity: Double) -> Double {
        floor + (ceiling - floor) * sensitivity
    }
    static func sensitivity(forThreshold t: Double) -> Double {
        (t - floor) / (ceiling - floor)
    }

    /// Seconds since the user last touched the keyboard.
    ///
    /// This reports *timing only*, never content, so unlike a global keyDown
    /// monitor it needs no Input Monitoring grant and no TCC prompt — which is
    /// what lets typing suppression run always-on instead of being an opt-in
    /// the user could never actually enable on an unsigned build.
    private var secondsSinceTyping: Double {
        let source = CGEventSourceStateID.combinedSessionState
        return min(
            CGEventSource.secondsSinceLastEventType(source, eventType: .keyDown),
            CGEventSource.secondsSinceLastEventType(source, eventType: .keyUp),
            CGEventSource.secondsSinceLastEventType(source, eventType: .flagsChanged)
        )
    }

    // MARK: - fallback

    private func enableTrackpadFallback(reason: String) {
        guard !isUsingTrackpadFallback else { return }
        isUsingTrackpadFallback = true
        isCalibrated = true     // nothing to calibrate; clicks are discrete
        Self.log.notice("falling back to trackpad tap mode — \(reason, privacy: .public)")

        // Global monitors only see events bound for *other* apps, so clicks on
        // Tappy's own recorder buttons can't register as taps here.
        trackpadMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self else { return }
            let now = Date.timeIntervalSinceReferenceDate
            guard now - self.lastTapAt > Self.cooldown else { return }
            self.lastTapAt = now
            self.onTap?()
        }
    }
}
