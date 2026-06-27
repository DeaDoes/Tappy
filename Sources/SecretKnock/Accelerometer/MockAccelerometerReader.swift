import Foundation

class MockAccelerometerReader: AccelerometerReaderProtocol {
    var handler: ((AccelerationSample) -> Void)?

    func start(interval: TimeInterval, handler: @escaping (AccelerationSample) -> Void) {
        self.handler = handler
    }

    func stop() { handler = nil }

    func simulateTap(magnitude: Double = 2.5) {
        handler?(AccelerationSample(x: magnitude, y: 0, z: 0, timestamp: Date()))
    }

    func simulateIdle() {
        handler?(AccelerationSample(x: 0.01, y: 0.01, z: 1.0, timestamp: Date()))
    }
}
