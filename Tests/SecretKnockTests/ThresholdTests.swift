import XCTest
@testable import SecretKnock

/// Pins the tap threshold against what was actually measured on this hardware.
///
/// The load-bearing fact: typing and tapping produce the *same size* chassis
/// spikes. Real working typing measured median 1181 / p95 2144 / max 3807,
/// while deliberate taps measured min 806 / median 1128 / max 2824.
///
/// So these tests deliberately do NOT assert that any slider position excludes
/// typing — none can. The slider only sets how firmly you must tap. What keeps
/// typing out is the timing gate, and that is asserted here too.
final class ThresholdTests: XCTestCase {
    private let relaxedTap: Double = 815
    private let hardestTap: Double = 2824

    func testWholeSliderRangeIsReachableByARealTap() {
        // Every position must be something a human can actually produce.
        XCTAssertLessThanOrEqual(AccelerometerTapDetector.threshold(for: 1.0), hardestTap)
    }

    func testGentlestSettingStillCatchesARelaxedTap() {
        XCTAssertLessThanOrEqual(AccelerometerTapDetector.threshold(for: 0.0), relaxedTap)
    }

    func testThresholdRisesWithTheSlider() {
        XCTAssertLessThan(AccelerometerTapDetector.threshold(for: 0.3),
                          AccelerometerTapDetector.threshold(for: 0.9))
    }

    func testSensitivityRoundTripsThroughThreshold() {
        for s in stride(from: 0.0, through: 1.0, by: 0.05) {
            let back = AccelerometerTapDetector.sensitivity(
                forThreshold: AccelerometerTapDetector.threshold(for: s))
            XCTAssertEqual(back, s, accuracy: 1e-9)
        }
    }

    func testTypingGateOutlastsAPauseBetweenWords() {
        // This, not the threshold, is what keeps typing out. Hands shifting on
        // the palm rest between words make tap-sized spikes tied to no
        // keystroke; a window under half a second demonstrably leaked.
        XCTAssertGreaterThanOrEqual(AccelerometerTapDetector.typingSuppressionWindowForTesting, 1.0)
    }

    func testNoiseFloorCannotRaiseTheBarOnAQuietMachine() {
        // Idle noise measured ~30, so 3x that must stay below the gentlest setting.
        XCTAssertLessThan(30.0 * 3, AccelerometerTapDetector.threshold(for: 0.0))
    }
}
