import Foundation

struct KnockPattern: Codable, Equatable {
    let intervals: [Double] // milliseconds between consecutive taps
    var tapCount: Int { intervals.count + 1 }
}

// In an extension so the memberwise init(intervals:) is still synthesized.
extension KnockPattern {
    init(taps: [Date]) {
        self.init(intervals: zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) * 1000 })
    }
}
