import XCTest
@testable import SecretKnock

/// The promise these lock down: **typing never triggers an action**, at every
/// setting including the lightest.
///
/// This cannot be done with a threshold. Measured on real hardware, working
/// typing produces chassis spikes of median 1181, p95 2144 and max 3807, while
/// deliberate taps run 806-2824 — the distributions overlap almost completely,
/// and at Light Tap (800) essentially every keystroke clears the bar. The only
/// thing standing between a keystroke and an action is the timing gate, so it
/// is asserted here directly rather than left to be inferred.
final class TypingGateTests: XCTestCase {
    private let window = AccelerometerTapDetector.typingSuppressionWindowForTesting

    func testAKeystrokeSpikeIsNeverAccepted() {
        // A spike caused by a keystroke lands within milliseconds of it.
        for msAfterKey in [0.0, 1, 5, 20, 50, 100, 200, 500, 900, 999] {
            XCTAssertFalse(
                AccelerometerTapDetector.acceptsTap(secondsSinceTyping: msAfterKey / 1000),
                "a spike \(msAfterKey)ms after a key event was accepted as a tap"
            )
        }
    }

    func testContinuousTypingIsFullySuppressed() {
        // Fast typing is ~5 keys/sec (200ms apart); even slow, deliberate typing
        // rarely exceeds one key per second. Every inter-key gap must be covered
        // or spikes leak between keystrokes — which is exactly what happened
        // when this window was 300ms.
        for gap in stride(from: 0.05, through: 1.0, by: 0.05) {
            XCTAssertFalse(AccelerometerTapDetector.acceptsTap(secondsSinceTyping: gap),
                           "a \(gap)s gap between keystrokes leaves a hole in the gate")
        }
    }

    func testADeliberateTapAfterAPauseIsStillAccepted() {
        // The gate must not make the app unusable: a tap once typing has stopped
        // has to work, or there is no product.
        for pause in [1.01, 1.5, 2.0, 5.0, 60.0] {
            XCTAssertTrue(AccelerometerTapDetector.acceptsTap(secondsSinceTyping: pause),
                          "a tap \(pause)s after typing was wrongly suppressed")
        }
    }

    func testTheGateIsIndependentOfTapStrength() {
        // The guarantee must not weaken at the lightest setting — that is the
        // case the user specifically asked about. acceptsTap takes no threshold
        // and no jerk, so strength cannot influence it; this test exists to make
        // that structural fact fail loudly if the signature ever grows one.
        let lightest = AccelerometerTapDetector.threshold(for: 0.0)
        XCTAssertEqual(lightest, AccelerometerTapDetector.floor)
        XCTAssertFalse(AccelerometerTapDetector.acceptsTap(secondsSinceTyping: 0.1))
    }

    func testWindowCoversTypingObservedInTheWild() {
        // A measured session leaked 37 of 75 taps while typing with a 0.3s
        // window. Anything at or below that is known-broken.
        XCTAssertGreaterThan(window, 0.3)
    }
}
