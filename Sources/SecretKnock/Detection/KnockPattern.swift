import Foundation

struct KnockPattern: Codable, Equatable {
    let intervals: [Double] // milliseconds between consecutive taps

    /// Set on a fixed-count knock ("any 3 taps"), left nil on a recorded rhythm.
    ///
    /// Optional and additive on purpose: knocks saved before fixed counts
    /// existed decode with this absent, so no stored mapping is invalidated and
    /// no schema versioning is needed yet.
    var ignoresRhythm: Bool?

    var tapCount: Int { intervals.count + 1 }
    var isFixedCount: Bool { ignoresRhythm == true }

    var summary: String {
        let taps = "\(tapCount) tap\(tapCount == 1 ? "" : "s")"
        return isFixedCount ? "Any \(taps)" : "\(taps), your rhythm"
    }
}

// In an extension so the memberwise init(intervals:) is still synthesized.
extension KnockPattern {
    init(taps: [Date]) {
        self.init(intervals: zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) * 1000 })
    }

    /// "Any N taps, whatever the rhythm." Intervals are placeholders that exist
    /// only to carry the count — the matcher never reads them.
    init(fixedCount: Int) {
        self.init(intervals: Array(repeating: 0, count: max(fixedCount, 1) - 1),
                  ignoresRhythm: true)
    }
}
