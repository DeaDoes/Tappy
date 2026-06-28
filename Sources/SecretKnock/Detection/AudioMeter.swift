import Foundation

// Publishes the current mic level so the settings UI can show a live meter
// while the user tunes sensitivity. Throttled so it doesn't spam SwiftUI.
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
