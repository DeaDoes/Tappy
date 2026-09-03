import XCTest
@testable import SecretKnock

final class KnockFeelTests: XCTestCase {
    private let relaxedTap: Double = 815   // weakest deliberate tap observed
    private let hardestTap: Double = 2824

    func testPresetsAreOrderedByEffortRequired() {
        let thresholds = KnockFeel.allCases.map(\.threshold)
        XCTAssertEqual(thresholds, thresholds.sorted())
    }

    func testEveryPresetIsReachableByARealTap() {
        // A preset above the hardest tap ever recorded is unusable.
        for feel in KnockFeel.allCases {
            XCTAssertLessThanOrEqual(feel.threshold, hardestTap, "\(feel.title) is unreachable")
        }
    }

    func testLightCatchesARelaxedTapAndSlapDoesNot() {
        XCTAssertLessThanOrEqual(KnockFeel.light.threshold, relaxedTap)
        XCTAssertGreaterThan(KnockFeel.slap.threshold, relaxedTap)
    }

    func testEveryPresetSurvivesTheSensitivityRoundTrip() {
        // Presets are stored as a sensitivity value, so the mapping has to be
        // lossless or the UI can't tell which preset is selected.
        for feel in KnockFeel.allCases {
            XCTAssertEqual(AccelerometerTapDetector.threshold(for: feel.sensitivity),
                           feel.threshold, accuracy: 0.001)
        }
    }

    func testPresetSensitivitiesStayInsideTheSliderRange() {
        for feel in KnockFeel.allCases {
            XCTAssertGreaterThanOrEqual(feel.sensitivity, 0.0)
            XCTAssertLessThanOrEqual(feel.sensitivity, 1.0)
        }
    }
}
