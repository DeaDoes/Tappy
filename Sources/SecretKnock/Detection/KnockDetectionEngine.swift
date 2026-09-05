import AppKit

class KnockDetectionEngine {
    static let shared = KnockDetectionEngine()

    private let detector = AccelerometerTapDetector()
    private let config = AppConfig.shared
    private var recentTaps: [Date] = []

    // A knock is "over" once this long passes with no tap. Too short and a
    // pattern containing a deliberate pause gets cut in half mid-performance —
    // both halves are then discarded, so the knock records fine and silently
    // never fires.
    //
    // A fixed window can't serve both a brisk tap-tap-tap and a knock with a
    // pause in it, so it follows the slowest pause the user actually saved,
    // with headroom for performing it slower than they recorded it. Patterns
    // stay expressive; people whose knocks are quick still get a quick trigger.
    static let minSettle: TimeInterval = 0.9
    static let maxRecordGap: TimeInterval = 2.0     // longest pause the recorder allows
    static let settleHeadroom = 1.5                 // performance-slower-than-recording margin
    static var maxSettle: TimeInterval { maxRecordGap * settleHeadroom }

    /// Whether a gap between two taps is one the matcher could still wait through.
    static func acceptsGap(_ gap: TimeInterval) -> Bool { gap <= maxRecordGap }

    /// The most taps any saved knock could need.
    ///
    /// Reaching it means no longer pattern exists to wait for, so the settle
    /// delay would only be latency the user feels. Zero when nothing is saved,
    /// which disables the shortcut rather than firing on the first tap.
    static func longestSavedKnock(in config: AppConfig) -> Int {
        let fromKnocks = config.mappings.map { $0.pattern.tapCount }.max() ?? 0
        let fromRules = config.contextAwareGestures
            ? (config.contextRules.map(\.tapCount).max() ?? 0)
            : 0
        return max(fromKnocks, fromRules)
    }

    /// Long enough to wait through the biggest pause any saved knock contains.
    static func settleDelay(for mappings: [KnockMapping]) -> TimeInterval {
        let longestPause = (mappings.flatMap { $0.pattern.intervals }.max() ?? 0) / 1000
        return min(max(minSettle, longestPause * settleHeadroom), maxSettle)
    }

    /// The app rule this knock should run, if any. Matched on tap count alone
    /// and checked before everything else: the point of the feature is that the
    /// same knock means something different while that app is in front, so a
    /// rule overrides a recorded rhythm of the same length too.
    static func contextRule(matching incoming: KnockPattern, in config: AppConfig,
                            frontmostBundleID: String?) -> ContextRule? {
        guard config.contextAwareGestures, let front = frontmostBundleID else { return nil }
        return config.contextRules.first {
            $0.bundleID == front && $0.tapCount == incoming.tapCount
        }
    }

    private let maxTaps = 16
    private var settleWork: DispatchWorkItem?
    var isRecordingMode = false

    /// True when the accelerometer never appeared and taps come from the trackpad.
    var isUsingTrackpadFallback: Bool { detector.isUsingTrackpadFallback }

    func start() {
        isRecordingMode = false
        detector.start { [weak self] in
            self?.handleTap()
        }
    }

    // Thresholding, hysteresis and the refractory gap all live in the detector
    // now — it sees the raw signal, so it can gate on it far better than a
    // score-shaped proxy could. Everything from here down is unchanged.
    private func handleTap() {
        let now = Date()
        NotificationCenter.default.post(name: .knockDetected, object: nil)
        if isRecordingMode { return }

        recentTaps.append(now)
        // Sustained rhythmic noise keeps pushing the settle timer back, so
        // evaluate() may not run for a long time. Cap the buffer.
        if recentTaps.count > maxTaps { recentTaps.removeFirst() }

        // Nothing saved is longer than what has already been knocked, so no
        // further tap could change the answer — act now instead of making the
        // user wait out a delay that exists only to let a longer knock finish.
        let longest = Self.longestSavedKnock(in: config)
        if longest > 0, recentTaps.count >= longest {
            settleWork?.cancel()
            evaluate()
            return
        }

        // Wait for a quiet gap before matching, so a 4-tap knock finishes
        // instead of a 3-tap knock firing on its way through.
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.evaluate() }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay(for: config.mappings), execute: work)
    }

    private func evaluate() {
        let taps = recentTaps
        recentTaps = []
        // One tap is a real knock now that a fixed-count mapping can ask for it.
        // With no 1-tap mapping saved, the loop below simply matches nothing.
        guard !taps.isEmpty else { return }

        let incoming = KnockPattern(taps: taps)

        // An app-specific rule wins outright, over the slots and over a
        // recorded rhythm of the same length.
        if let rule = Self.contextRule(matching: incoming, in: config,
                                       frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
            ActionLauncher.launch(rule.action)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            return
        }

        // Exact tap count, so a 3-tap and a 4-tap knock can't be confused. Fires
        // every match, which only exceeds one when shared rhythm is on.
        var fired = false
        for mapping in config.mappings where mapping.pattern.tapCount == taps.count {
            if KnockMatcher.matches(incoming, against: mapping.pattern) {
                ActionLauncher.launch(mapping.action)
                fired = true
            }
        }
        if fired { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default) }
    }
}

extension Notification.Name {
    static let knockDetected = Notification.Name("knockDetected")
}
