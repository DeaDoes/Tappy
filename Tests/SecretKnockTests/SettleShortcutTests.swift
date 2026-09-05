import XCTest
@testable import SecretKnock

/// The settle delay exists so a longer knock can finish before matching runs.
/// Once a knock is already as long as the longest saved one, that wait is pure
/// latency — these pin down when it can be skipped.
final class SettleShortcutTests: IsolatedConfigTestCase {
    func testNothingSavedDisablesTheShortcut() {
        XCTAssertEqual(KnockDetectionEngine.longestSavedKnock(in: config), 0,
                       "zero must disable it, or the first tap would fire immediately")
    }

    func testItIsTheLongestKnockAcrossSlotsAndRhythms() {
        config.assign(.copy, to: .double)
        XCTAssertEqual(KnockDetectionEngine.longestSavedKnock(in: config), 2)

        config.mappings.append(KnockMapping(name: "Long",
                                            pattern: KnockPattern(intervals: [200, 200, 200, 200]),
                                            action: .mute))
        XCTAssertEqual(KnockDetectionEngine.longestSavedKnock(in: config), 5,
                       "a 5-tap rhythm still needs its wait after 2 taps")
    }

    func testContextRulesCountOnlyWhileTheFeatureIsOn() {
        config.assign(.copy, to: .single)
        config.contextRules = [ContextRule(bundleID: "com.brave.Browser", tapCount: 3, action: .mute)]
        XCTAssertEqual(KnockDetectionEngine.longestSavedKnock(in: config), 1,
                       "rules are ignored while the toggle is off")

        config.contextAwareGestures = true
        XCTAssertEqual(KnockDetectionEngine.longestSavedKnock(in: config), 3)
    }
}
