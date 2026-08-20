import Foundation

// Live mic level for the sensitivity meter in Settings.
final class AudioMeter: ObservableObject {
    static let shared = AudioMeter()
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
