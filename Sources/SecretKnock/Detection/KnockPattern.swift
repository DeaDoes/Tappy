import Foundation

struct KnockPattern: Codable, Equatable {
    let intervals: [Double] // milliseconds between consecutive taps
    var tapCount: Int { intervals.count + 1 }

    init(intervals: [Double]) {
        self.intervals = intervals
    }

    init(taps: [Date]) {
        intervals = zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) * 1000 }
    }
}
