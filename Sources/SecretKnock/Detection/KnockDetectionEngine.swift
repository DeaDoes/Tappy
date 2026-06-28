import Foundation

class KnockDetectionEngine {
    static let shared = KnockDetectionEngine()

    private let reader: AccelerometerReaderProtocol
    private let config: AppConfig
    private var recentTaps: [Date] = []
    private var lastTapTime: Date = .distantPast
    // ponytail: 0.2s refractory + hysteresis below = one knock counts once even as it rings
    private let minTapInterval: TimeInterval = 0.2
    // Wait this long after the last tap before deciding which knock it was.
    private let settleDelay: TimeInterval = 0.65
    private var settleWork: DispatchWorkItem?
    private var aboveThreshold = false
    var isRecordingMode = false

    init(reader: AccelerometerReaderProtocol = AccelerometerReader(), config: AppConfig = .shared) {
        self.reader = reader
        self.config = config
    }

    func start() {
        isRecordingMode = false
        reader.start(interval: 0.02) { [weak self] sample in
            self?.process(sample)
        }
    }

    func stop() { reader.stop() }

    private func process(_ sample: AccelerationSample) {
        // Hysteresis: a tap fires only on the rising edge past sensitivity,
        // and the level must fall below half before another tap can fire.
        if aboveThreshold {
            if sample.magnitude < config.sensitivity * 0.5 { aboveThreshold = false }
            return
        }
        guard sample.magnitude > config.sensitivity else { return }
        aboveThreshold = true

        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > minTapInterval else { return }
        lastTapTime = now

        // Always tell any listening UI (the pattern recorder) a tap happened.
        NotificationCenter.default.post(name: .knockDetected, object: nil)

        // While recording a new pattern, don't try to match or fire actions.
        if isRecordingMode { return }

        recentTaps.append(now)

        // Don't match yet — the user may still be knocking. Wait for a quiet
        // gap, then evaluate the whole sequence. This lets a 4-tap knock finish
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

        let recorder = KnockRecorder()
        taps.forEach { recorder.recordTap(at: $0) }
        let incoming = recorder.finish()

        // Match by exact tap count so a 3-tap and a 4-tap knock can't be confused.
        for mapping in config.mappings where mapping.pattern.tapCount == taps.count {
            if KnockMatcher.matches(incoming, against: mapping.pattern) {
                HapticFeedback.confirm()
                ActionLauncher.launch(mapping.action)
                return
            }
        }
    }
}

extension Notification.Name {
    static let knockDetected = Notification.Name("knockDetected")
}
