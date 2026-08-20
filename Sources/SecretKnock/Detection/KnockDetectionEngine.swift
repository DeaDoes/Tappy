import AppKit

class KnockDetectionEngine {
    static let shared = KnockDetectionEngine()

    private let listener = MicListener()
    private let config = AppConfig.shared
    private var recentTaps: [Date] = []
    private var lastTapTime: Date = .distantPast
    // Refractory period; with the hysteresis below, one knock counts once as it rings.
    private let minTapInterval: TimeInterval = 0.2

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

    /// Long enough to wait through the biggest pause any saved knock contains.
    static func settleDelay(for mappings: [KnockMapping]) -> TimeInterval {
        let longestPause = (mappings.flatMap { $0.pattern.intervals }.max() ?? 0) / 1000
        return min(max(minSettle, longestPause * settleHeadroom), maxSettle)
    }

    private let maxTaps = 16
    private var settleWork: DispatchWorkItem?
    private var aboveThreshold = false
    var isRecordingMode = false

    func start() {
        isRecordingMode = false
        listener.start { [weak self] score in
            self?.process(score)
        }
    }

    private func process(_ score: Double) {
        // Hysteresis: fire on the rising edge only, and not again until the
        // level falls below half.
        if aboveThreshold {
            if score < config.sensitivity * 0.5 { aboveThreshold = false }
            return
        }
        guard score > config.sensitivity else { return }
        aboveThreshold = true

        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > minTapInterval else { return }
        lastTapTime = now

        NotificationCenter.default.post(name: .knockDetected, object: nil)
        if isRecordingMode { return }

        recentTaps.append(now)
        // Sustained rhythmic noise keeps pushing the settle timer back, so
        // evaluate() may not run for a long time. Cap the buffer.
        if recentTaps.count > maxTaps { recentTaps.removeFirst() }

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
        guard taps.count >= 2 else { return }

        let incoming = KnockPattern(taps: taps)

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
