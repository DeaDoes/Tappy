import Foundation

// Live tap level for the strength readout in Settings, reported as a multiple
// of the fixed trigger point so the meter is unit-free.
final class TapMeter: ObservableObject {
    static let shared = TapMeter()
    @Published var level: Double = 0
    private var lastPush = Date.distantPast
    private init() {}

    func report(_ value: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastPush) > 0.05 else { return } // ~20 Hz
        lastPush = now
        DispatchQueue.main.async { self.level = value }
    }
}
