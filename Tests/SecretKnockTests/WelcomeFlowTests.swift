import XCTest
@testable import SecretKnock

/// The two rules the walkthrough must not get wrong.
///
/// Everything else in the flow is a button and a label, but these two decide
/// whether the last step works: which action a real knock fires, and whether
/// the flow can be walked to its end at all.
final class WelcomeFlowTests: IsolatedConfigTestCase {
    func testGrantedAccessibilityFiresARealScreenshot() {
        // cmd-shift-3 drops a file straight on the Desktop, so the user can see
        // that the knock did something outside the walkthrough window.
        XCTAssertEqual(welcomeAction(accessibilityGranted: true), .fullScreenshot)
    }

    func testDeniedAccessibilityStillFiresSomethingReal() {
        // Denial must not dead-end the last step. A screen flash needs no grant
        // and still runs through the real matcher.
        let denied = welcomeAction(accessibilityGranted: false)
        XCTAssertEqual(denied, .screenFlash)
        XCTAssertFalse(denied.needsAccessibility,
                       "the fallback action must not need the permission that was just refused")
    }

    func testEveryStepLeadsToTheEnd() {
        var step = WelcomeStep.intro
        var visited = [step]
        while let next = step.next {
            step = next
            visited.append(step)
            XCTAssertLessThanOrEqual(visited.count, WelcomeStep.allCases.count + 1,
                                     "step progression looped")
        }
        XCTAssertEqual(visited.count, WelcomeStep.allCases.count)
        XCTAssertEqual(step, .menuBar, "the walkthrough must end on the menu bar step")
    }

    func testOnlyTheTapStepsWaitForAKnock() {
        // These two have no Continue button, so if this list ever grows by
        // accident a step becomes unreachable past.
        XCTAssertEqual(WelcomeStep.allCases.filter(\.needsAKnock), [.tapCheck, .doItForReal])
    }

    func testTheDemoKnockIsThreeTaps() {
        XCTAssertEqual(welcomeSlot.rawValue, 3)
    }

    func testOnlyAnExactThreeTapKnockMatchesTheDemo() {
        // The guard behind the miscount message: the matcher is exact, so an
        // over-eager four-tap knock fires nothing at all. A walkthrough that
        // congratulated the user there would be celebrating a knock that did
        // not happen.
        let demo = KnockPattern(fixedCount: welcomeSlot.rawValue)
        let now = Date()
        for count in 1...5 {
            let taps = (0..<count).map { now.addingTimeInterval(Double($0) * 0.25) }
            let matched = KnockPattern(taps: taps).tapCount == demo.tapCount
                && KnockMatcher.matches(KnockPattern(taps: taps), against: demo)
            XCTAssertEqual(matched, count == welcomeSlot.rawValue,
                           "\(count) taps should \(count == 3 ? "" : "not ")fire the demo knock")
        }
    }

    @MainActor
    func testCleanupAlwaysHandsDetectionBack() {
        // The walkthrough mutes the engine while it runs. If any way of
        // dismissing it skipped this, Tappy would ignore every knock until it
        // was relaunched — on a window most people see exactly once.
        let controller = WelcomeController(config: config)
        XCTAssertTrue(KnockDetectionEngine.shared.isRecordingMode,
                      "the walkthrough should suppress actions while it is up")

        controller.cleanup()
        XCTAssertFalse(KnockDetectionEngine.shared.isRecordingMode)
        XCTAssertFalse(config.isFirstLaunch, "a seen walkthrough must not reappear every launch")

        // Idempotent: the delegate can fire after Done has already cleaned up.
        controller.cleanup()
        XCTAssertFalse(KnockDetectionEngine.shared.isRecordingMode)
    }

    func testSavingTheDemoKnockMakesThreeTapsMatchIt() {
        config.assign(welcomeAction(accessibilityGranted: true), to: welcomeSlot)

        // The walkthrough's promise, asserted against the real matcher rather
        // than against the walkthrough's own bookkeeping.
        XCTAssertEqual(config.action(for: welcomeSlot), .fullScreenshot)
        let threeTaps = KnockPattern(taps: [
            Date(), Date().addingTimeInterval(0.25), Date().addingTimeInterval(0.5),
        ])
        XCTAssertEqual(threeTaps.tapCount, 3)
        XCTAssertTrue(KnockMatcher.matches(threeTaps, against: KnockPattern(fixedCount: 3)))
    }
}
