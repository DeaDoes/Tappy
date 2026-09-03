import XCTest
@testable import SecretKnock

/// The idle-noise term raises the trigger on a machine loud enough to fire
/// itself. Its failure mode is nastier than it looks: calibration runs for the
/// first 1.5s after launch, and tapping the case right then to see whether the
/// app works is the most natural thing a user can do. Uncapped, that one tap
/// becomes the noise estimate and the app is deaf until relaunch — silently.
final class NoiseFloorTests: XCTestCase {
    private let quietMachine: Double = 30      // measured idle noise on this Mac
    private let hardestTap: Double = 2824

    func testAQuietMachineIsUnaffected() {
        for s in [0.0, 0.5, 1.0] {
            XCTAssertEqual(
                AccelerometerTapDetector.threshold(sensitivity: s, noiseCeiling: quietMachine),
                AccelerometerTapDetector.threshold(for: s),
                accuracy: 0.001
            )
        }
    }

    func testATapDuringCalibrationCannotDeafenTheApp() {
        // A hard tap reads in the thousands; typing has been seen above 60000.
        for rogue in [2000.0, 8000, 62397] {
            let t = AccelerometerTapDetector.threshold(sensitivity: 0, noiseCeiling: rogue)
            XCTAssertLessThanOrEqual(t, hardestTap,
                                     "noiseCeiling=\(rogue) pushed the trigger beyond any real tap")
        }
    }

    func testAGenuinelyNoisyMachineStillRaisesTheBar() {
        // The term has to keep doing its job, not just be clamped away.
        let noisy = AccelerometerTapDetector.threshold(sensitivity: 0, noiseCeiling: 500)
        XCTAssertGreaterThan(noisy, AccelerometerTapDetector.threshold(for: 0))
    }

    func testItNeverLowersTheUsersChosenStrength() {
        for noise in [0.0, 100, 500, 5000] {
            XCTAssertGreaterThanOrEqual(
                AccelerometerTapDetector.threshold(sensitivity: 1.0, noiseCeiling: noise),
                AccelerometerTapDetector.threshold(for: 1.0)
            )
        }
    }
}
