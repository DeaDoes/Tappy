import Foundation

enum KnockMatcher {
    static func matches(_ incoming: KnockPattern, against saved: KnockPattern, tolerance: Double = 0.40) -> Bool {
        guard incoming.intervals.count == saved.intervals.count,
              !saved.intervals.isEmpty else { return false }

        let savedRatios = ratios(of: saved.intervals)
        let incomingRatios = ratios(of: incoming.intervals)

        return zip(savedRatios, incomingRatios).allSatisfy { s, i in
            abs(s - i) / max(s, 0.001) <= tolerance
        }
    }

    // The saved knock (if any) whose rhythm this pattern would also trigger —
    // i.e. saving it would make a knock ambiguous. Used to block duplicates.
    // Pass the mapping's own id when editing so it doesn't clash with itself.
    static func clash(with pattern: KnockPattern, in mappings: [KnockMapping], excluding id: UUID? = nil) -> KnockMapping? {
        mappings.first {
            $0.id != id && $0.pattern.tapCount == pattern.tapCount && matches(pattern, against: $0.pattern)
        }
    }

    // Normalize each interval by the average, not the first — a noisy first
    // knock shouldn't skew the whole comparison. Scale-invariant: knocking the
    // same rhythm faster or slower still matches, which is the intended UX.
    private static func ratios(of intervals: [Double]) -> [Double] {
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return intervals }
        return intervals.map { $0 / mean }
    }
}
