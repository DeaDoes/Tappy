import XCTest
@testable import SecretKnock

/// Version comparison decides whether every user gets told to update, so the
/// off-by-one cases matter more than the obvious ones.
final class UpdateCheckerTests: XCTestCase {
    func testAHigherVersionIsNewer() {
        XCTAssertTrue(UpdateChecker.isVersion("1.3", newerThan: "1.2"))
        XCTAssertTrue(UpdateChecker.isVersion("2.0", newerThan: "1.9"))
        XCTAssertTrue(UpdateChecker.isVersion("1.2.1", newerThan: "1.2"))
    }

    func testTheSameVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isVersion("1.2", newerThan: "1.2"))
        // Missing components read as zero, so these are the same release and
        // must not nag a user who is already on it.
        XCTAssertFalse(UpdateChecker.isVersion("1.2", newerThan: "1.2.0"))
        XCTAssertFalse(UpdateChecker.isVersion("1.2.0", newerThan: "1.2"))
    }

    func testAnOlderVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isVersion("1.2", newerThan: "1.3"))
        XCTAssertFalse(UpdateChecker.isVersion("1.9", newerThan: "2.0"))
    }

    /// Compared as numbers, not as text — "1.10" ships after "1.9".
    func testDoubleDigitsCompareNumericallyNotAlphabetically() {
        XCTAssertTrue(UpdateChecker.isVersion("1.10", newerThan: "1.9"))
        XCTAssertFalse(UpdateChecker.isVersion("1.9", newerThan: "1.10"))
    }

    /// The tag is "v1.3"; the caller strips the v, but a stray one must not
    /// turn the component into zero and silently hide a release.
    func testNonNumericCharactersAreIgnored() {
        XCTAssertTrue(UpdateChecker.isVersion("v1.3", newerThan: "1.2"))
        XCTAssertTrue(UpdateChecker.isVersion("1.3-beta", newerThan: "1.2"))
    }
}
