import Foundation

struct AccelerationSample {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Date

    var magnitude: Double { sqrt(x*x + y*y + z*z) }
}

protocol AccelerometerReaderProtocol {
    func start(interval: TimeInterval, handler: @escaping (AccelerationSample) -> Void)
    func stop()
}
