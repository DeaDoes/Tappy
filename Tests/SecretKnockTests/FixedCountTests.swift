import XCTest
@testable import SecretKnock

final class FixedCountTests: XCTestCase {
    private func rhythm(_ intervals: [Double]) -> KnockPattern {
        KnockPattern(intervals: intervals)
    }

    func testFixedCountMatchesAnyRhythmOfThatLength() {
        let saved = KnockPattern(fixedCount: 3)
        XCTAssertTrue(KnockMatcher.matches(rhythm([120, 400]), against: saved))
        XCTAssertTrue(KnockMatcher.matches(rhythm([900, 100]), against: saved))
    }

    func testFixedCountRejectsAWrongTapCount() {
        let saved = KnockPattern(fixedCount: 3)
        XCTAssertFalse(KnockMatcher.matches(rhythm([200]), against: saved))
        XCTAssertFalse(KnockMatcher.matches(rhythm([200, 200, 200]), against: saved))
    }

    func testFixedCountCarriesTheRightTapCount() {
        XCTAssertEqual(KnockPattern(fixedCount: 1).tapCount, 1)
        XCTAssertEqual(KnockPattern(fixedCount: 3).tapCount, 3)
    }

    func testASavedRhythmStillNeedsItsRhythm() {
        // The fixed-count shortcut must not leak into ordinary patterns.
        let saved = rhythm([100, 400])
        XCTAssertFalse(saved.isFixedCount)
        XCTAssertFalse(KnockMatcher.matches(rhythm([400, 100]), against: saved))
    }

    func testFixedCountClashesWithARhythmOfTheSameLength() {
        // Either order: whichever exists first swallows the other, because a
        // fixed count fires on every rhythm of that length.
        let existing = [KnockMapping(name: "Any three",
                                     pattern: KnockPattern(fixedCount: 3),
                                     action: .openURL(URL(string: "https://example.com")!))]
        XCTAssertNotNil(KnockMatcher.clash(with: rhythm([120, 400]), in: existing))

        let reverse = [KnockMapping(name: "My rhythm",
                                    pattern: rhythm([120, 400]),
                                    action: .openURL(URL(string: "https://example.com")!))]
        XCTAssertNotNil(KnockMatcher.clash(with: KnockPattern(fixedCount: 3), in: reverse))
    }

    func testFixedCountDoesNotClashAcrossDifferentLengths() {
        let existing = [KnockMapping(name: "Any two",
                                     pattern: KnockPattern(fixedCount: 2),
                                     action: .openURL(URL(string: "https://example.com")!))]
        XCTAssertNil(KnockMatcher.clash(with: KnockPattern(fixedCount: 3), in: existing))
    }

    func testKnocksSavedBeforeFixedCountsExistedStillDecode() {
        // The stored shape had no ignoresRhythm key; it must decode as a rhythm,
        // not silently become a fixed-count knock that fires on anything.
        let legacy = #"{"intervals":[120,400]}"#.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(KnockPattern.self, from: legacy)
        XCTAssertEqual(decoded?.intervals, [120, 400])
        XCTAssertEqual(decoded?.isFixedCount, false)
    }
}
