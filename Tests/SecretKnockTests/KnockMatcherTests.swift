import XCTest
@testable import SecretKnock

final class KnockMatcherTests: XCTestCase {
    let saved = KnockPattern(intervals: [300, 150, 300])

    func test_identical_matches() {
        XCTAssertTrue(KnockMatcher.matches(KnockPattern(intervals: [300, 150, 300]), against: saved))
    }

    func test_10_percent_slower_matches() {
        XCTAssertTrue(KnockMatcher.matches(KnockPattern(intervals: [330, 165, 330]), against: saved))
    }

    func test_even_rhythm_does_not_match() {
        XCTAssertFalse(KnockMatcher.matches(KnockPattern(intervals: [300, 300, 300]), against: saved))
    }

    func test_wrong_tap_count_does_not_match() {
        XCTAssertFalse(KnockMatcher.matches(KnockPattern(intervals: [300, 150]), against: saved))
    }

    func test_empty_pattern_never_matches() {
        XCTAssertFalse(KnockMatcher.matches(KnockPattern(intervals: []), against: KnockPattern(intervals: [])))
    }

    func test_same_rhythm_slower_still_matches() {
        // Uniformly 50% slower = same rhythm, must still unlock.
        XCTAssertTrue(KnockMatcher.matches(KnockPattern(intervals: [450, 225, 450]), against: saved))
    }

    func test_different_rhythm_does_not_match() {
        // First gap long, rest short — a genuinely different pattern.
        XCTAssertFalse(KnockMatcher.matches(KnockPattern(intervals: [600, 150, 150]), against: saved))
    }
}
