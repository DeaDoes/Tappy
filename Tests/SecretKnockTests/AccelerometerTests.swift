import XCTest
@testable import SecretKnock

final class AccelerometerTests: XCTestCase {
    func test_mock_delivers_samples() {
        let mock = MockAccelerometerReader()
        var received: [AccelerationSample] = []
        mock.start(interval: 0.01) { received.append($0) }
        mock.simulateTap()
        mock.simulateIdle()
        XCTAssertEqual(received.count, 2)
        XCTAssertGreaterThan(received[0].magnitude, received[1].magnitude)
    }
}
