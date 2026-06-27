import Foundation

class KnockRecorder {
    private var timestamps: [Date] = []
    var tapCount: Int { timestamps.count }

    func recordTap(at date: Date = Date()) {
        timestamps.append(date)
    }

    func finish() -> KnockPattern {
        let intervals = zip(timestamps, timestamps.dropFirst()).map { a, b in
            b.timeIntervalSince(a) * 1000
        }
        return KnockPattern(intervals: intervals)
    }

    func reset() { timestamps = [] }
}
