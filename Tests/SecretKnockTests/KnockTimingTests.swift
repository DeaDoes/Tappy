import XCTest
@testable import SecretKnock

/// The recorder and the matcher have to agree about time. Recording collects
/// taps with no deadline; matching gives up once a knock has been quiet for
/// `settleDelay` and evaluates whatever it has. If the recorder accepts a pause
/// the matcher won't wait through, the knock saves fine and then never fires —
/// which is exactly the bug these tests exist to prevent coming back.
final class KnockTimingTests: XCTestCase {

    private func mapping(gapsMS: [Double]) -> KnockMapping {
        KnockMapping(name: "t", pattern: KnockPattern(intervals: gapsMS),
                     action: .openURL(URL(string: "https://example.com")!))
    }

    func testWaitsLongEnoughForTheSlowestPauseEverRecorded() {
        // The knock that exposed this: 4 taps with a 1.6s pause in the middle.
        let m = mapping(gapsMS: [395, 1600, 405])
        XCTAssertGreaterThan(
            KnockDetectionEngine.settleDelay(for: [m]), 1.6,
            "A pattern the recorder accepted must not be cut in half at match time."
        )
    }

    func testAnyRecordableGapIsOneTheMatcherWillWaitThrough() {
        let atLimit = mapping(gapsMS: [KnockDetectionEngine.maxRecordGap * 1000])
        XCTAssertGreaterThan(
            KnockDetectionEngine.settleDelay(for: [atLimit]),
            KnockDetectionEngine.maxRecordGap,
            "The longest recordable pause must still fit inside the settle window."
        )
    }

    func testQuickKnocksKeepAQuickTrigger() {
        let brisk = mapping(gapsMS: [200, 200])
        XCTAssertEqual(KnockDetectionEngine.settleDelay(for: [brisk]),
                       KnockDetectionEngine.minSettle,
                       "A fast pattern shouldn't inherit a slow pattern's latency.")
    }

    func testSettleWindowIsCappedSoATriggerCantHangForever() {
        let absurd = mapping(gapsMS: [99_000])
        XCTAssertEqual(KnockDetectionEngine.settleDelay(for: [absurd]),
                       KnockDetectionEngine.maxSettle)
    }

    func testRecorderRejectsAPauseTheMatcherWouldGiveUpOn() {
        XCTAssertTrue(KnockDetectionEngine.acceptsGap(KnockDetectionEngine.maxRecordGap))
        XCTAssertFalse(KnockDetectionEngine.acceptsGap(KnockDetectionEngine.maxRecordGap + 0.01))
    }

    func testNoSavedKnocksStillGivesAUsableWindow() {
        XCTAssertEqual(KnockDetectionEngine.settleDelay(for: []), KnockDetectionEngine.minSettle)
    }
}
