import XCTest
@testable import SecretKnock

final class KnockRecorderTests: XCTestCase {
    func test_records_single_tap() {
        let recorder = KnockRecorder()
        recorder.recordTap(at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(recorder.tapCount, 1)
    }

    func test_pattern_interval_count() {
        let recorder = KnockRecorder()
        let base = Date(timeIntervalSince1970: 0)
        recorder.recordTap(at: base)
        recorder.recordTap(at: base.addingTimeInterval(0.3))
        recorder.recordTap(at: base.addingTimeInterval(0.45))
        recorder.recordTap(at: base.addingTimeInterval(0.75))
        XCTAssertEqual(recorder.finish().intervals.count, 3)
    }

    func test_interval_in_milliseconds() {
        let recorder = KnockRecorder()
        let base = Date(timeIntervalSince1970: 0)
        recorder.recordTap(at: base)
        recorder.recordTap(at: base.addingTimeInterval(0.3))
        XCTAssertEqual(recorder.finish().intervals[0], 300, accuracy: 1)
    }

    func test_reset_clears_taps() {
        let recorder = KnockRecorder()
        recorder.recordTap(at: Date())
        recorder.reset()
        XCTAssertEqual(recorder.tapCount, 0)
    }
}
