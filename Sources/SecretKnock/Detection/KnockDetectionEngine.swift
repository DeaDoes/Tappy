import AppKit

class KnockDetectionEngine {
    static let shared = KnockDetectionEngine()

    private let listener = MicListener()
    private let config = AppConfig.shared
    private var recentTaps: [Date] = []
    private var lastTapTime: Date = .distantPast
    // Refractory period; with the hysteresis below, one knock counts once as it rings.
    private let minTapInterval: TimeInterval = 0.2
    private let settleDelay: TimeInterval = 0.65
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
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: work)
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
