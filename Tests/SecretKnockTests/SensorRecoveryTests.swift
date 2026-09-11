import XCTest
@testable import SecretKnock

/// Pins the two rules that decide whether the app is hearing the sensor at all.
///
/// Both were real failures. Two HID nodes match usage page 0xFF00 / usage 3 on
/// Apple Silicon — the sensor at a 22-byte report, and the Apple Internal
/// Keyboard / Trackpad at a 108-byte one — and opening the second gained
/// nothing but an Input Monitoring grant and 800 dropped reports a second.
/// Separately, a running stream can stop with no error and no callback, which
/// left the app silently deaf for the rest of the session.
final class SensorRecoveryTests: XCTestCase {
    func testOnlyTheTwentyTwoByteNodeIsTreatedAsTheSensor() {
        XCTAssertTrue(AccelerometerTapDetector.isSensor(reportSize: 22))
        // The internal keyboard/trackpad, which matches the same usage page.
        XCTAssertFalse(AccelerometerTapDetector.isSensor(reportSize: 108))
        // A device that never told us its report size is not a sensor either.
        XCTAssertFalse(AccelerometerTapDetector.isSensor(reportSize: 0))
    }

    func testAStreamThatDeliveredNothingNewHasStalled() {
        XCTAssertTrue(AccelerometerTapDetector.hasStalled(reportCount: 4_000, since: 4_000))
    }

    func testAStreamStillDeliveringHasNotStalled() {
        // Measured idle rate is ~795 Hz and flat, so even one new report over a
        // whole interval means the sensor is still free-running.
        XCTAssertFalse(AccelerometerTapDetector.hasStalled(reportCount: 7_972, since: 4_000))
        XCTAssertFalse(AccelerometerTapDetector.hasStalled(reportCount: 4_001, since: 4_000))
    }
}
