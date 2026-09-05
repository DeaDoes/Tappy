import Foundation

enum KnockMatcher {
    static func matches(_ incoming: KnockPattern, against saved: KnockPattern, tolerance: Double = 0.40) -> Bool {
        // A fixed-count knock is satisfied by the tap count alone. Callers
        // already filter on tapCount, so rhythm simply doesn't apply here.
        guard !saved.isFixedCount else { return incoming.tapCount == saved.tapCount }

        guard incoming.intervals.count == saved.intervals.count,
              !saved.intervals.isEmpty else { return false }

        let savedRatios = ratios(of: saved.intervals)
        let incomingRatios = ratios(of: incoming.intervals)

        return zip(savedRatios, incomingRatios).allSatisfy { s, i in
            abs(s - i) / max(s, 0.001) <= tolerance
        }
    }

    // The saved knock this pattern would also trigger. Pass the mapping's own
    // id when editing so it doesn't clash with itself.
    static func clash(with pattern: KnockPattern, in mappings: [KnockMapping], excluding id: UUID? = nil) -> KnockMapping? {
        mappings.first {
            guard $0.id != id, $0.pattern.tapCount == pattern.tapCount else { return false }
            // Stacking a fixed-count knock with a rhythm of the same length is
            // deliberate, not a mistake: it is how one knock runs several
            // actions at once. Both fire, and neither blocks saving the other.
            //
            // A clash here is only ever the ambiguous case — two recorded
            // rhythms so alike that performing one also matches the other, so
            // the user cannot choose between them.
            // Only the mixed pair is exempt. Two fixed counts of the same
            // length are the one case that really is indistinguishable —
            // "any 3 taps" twice over — so that still clashes.
            if $0.pattern.isFixedCount != pattern.isFixedCount { return false }
            return matches(pattern, against: $0.pattern)
        }
    }

    // By the average, not the first, so a noisy first knock can't skew it. Makes
    // matching scale-invariant: the same rhythm faster or slower still matches.
    private static func ratios(of intervals: [Double]) -> [Double] {
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return intervals }
        return intervals.map { $0 / mean }
    }
}
