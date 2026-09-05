import XCTest
@testable import SecretKnock

final class ContextRuleTests: IsolatedConfigTestCase {
    private let braveTriple = ContextRule(bundleID: "com.brave.Browser", tapCount: 3, action: .closeTab)

    // Every test here is about what rules do once they are switched on; the one
    // test about the switch being off turns it back off itself.
    override func setUp() {
        super.setUp()
        config.contextAwareGestures = true
    }

    func testRuleFiresForItsAppAndTapCount() {
        config.assign(.screenshot, to: .triple)
        config.contextRules = [braveTriple]
        let rule = KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [200, 200]),
            in: config, frontmostBundleID: "com.brave.Browser")
        XCTAssertEqual(rule?.action, .closeTab)
    }

    func testRuleIsIgnoredForAnotherAppOrAnotherCount() {
        config.contextRules = [braveTriple]
        XCTAssertNil(KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [200, 200]),
            in: config, frontmostBundleID: "com.apple.Safari"))
        XCTAssertNil(KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [200]),
            in: config, frontmostBundleID: "com.brave.Browser"))
    }

    /// Only one rule per app and knock can ever run, so a second must replace
    /// the first instead of sitting there dead.
    func testAddingASecondRuleForTheSameAppAndKnockReplacesTheFirst() {
        config.setContextRule(.spotlight, forApp: "com.brave.Browser", slot: .triple)
        config.setContextRule(.closeTab, forApp: "com.brave.Browser", slot: .triple)
        XCTAssertEqual(config.contextRules.count, 1)
        XCTAssertEqual(config.contextRules.first?.action, .closeTab)

        // A different knock in the same app is a separate rule, not a replacement.
        config.setContextRule(.mute, forApp: "com.brave.Browser", slot: .double)
        XCTAssertEqual(config.contextRules.count, 2)
    }

    func testRuleIsIgnoredWhileTheFeatureIsOff() {
        config.contextRules = [braveTriple]
        config.contextAwareGestures = false
        XCTAssertNil(KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [200, 200]),
            in: config, frontmostBundleID: "com.brave.Browser"))
    }

    /// The feature is "this knock means something else in this app", so a rule
    /// takes over a recorded rhythm of the same length while its app is front.
    func testARuleOverridesARecordedRhythmOfTheSameLength() {
        config.mappings = [KnockMapping(name: "Open Chrome",
                                        pattern: KnockPattern(intervals: [150, 450]),
                                        action: .openApp(bundleID: "com.google.Chrome"))]
        config.contextRules = [braveTriple]
        let rule = KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [150, 450]),
            in: config, frontmostBundleID: "com.brave.Browser")
        XCTAssertEqual(rule?.action, .closeTab)
    }

    /// And the rhythm gets its own meaning back the moment another app is front.
    func testTheRhythmIsUntouchedInEveryOtherApp() {
        config.mappings = [KnockMapping(name: "Open Chrome",
                                        pattern: KnockPattern(intervals: [150, 450]),
                                        action: .openApp(bundleID: "com.google.Chrome"))]
        config.contextRules = [braveTriple]
        XCTAssertNil(KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [150, 450]),
            in: config, frontmostBundleID: "com.apple.Safari"))
    }

    func testAnyThreeTapKnockHitsTheRule() {
        config.mappings = [KnockMapping(name: "Open Chrome",
                                        pattern: KnockPattern(intervals: [150, 450]),
                                        action: .openApp(bundleID: "com.google.Chrome"))]
        config.contextRules = [braveTriple]
        let rule = KnockDetectionEngine.contextRule(
            matching: KnockPattern(intervals: [400, 150]),
            in: config, frontmostBundleID: "com.brave.Browser")
        XCTAssertEqual(rule?.action, .closeTab)
    }
}
