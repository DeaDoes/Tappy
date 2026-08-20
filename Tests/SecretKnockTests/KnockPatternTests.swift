import XCTest
@testable import SecretKnock

final class KnockPatternTests: XCTestCase {
    func test_intervals_from_taps() {
        let base = Date(timeIntervalSince1970: 0)
        let taps = [base, base.addingTimeInterval(0.3),
                    base.addingTimeInterval(0.45), base.addingTimeInterval(0.75)]
        let pattern = KnockPattern(taps: taps)
        XCTAssertEqual(pattern.intervals.count, 3)
        XCTAssertEqual(pattern.tapCount, 4)
        XCTAssertEqual(pattern.intervals[0], 300, accuracy: 1) // milliseconds
    }

    func test_single_tap_has_no_intervals() {
        XCTAssertEqual(KnockPattern(taps: [Date()]).intervals, [])
    }
}
