import AVFoundation

class AccelerometerReader: AccelerometerReaderProtocol {
    private let audioEngine = AVAudioEngine()

    func start(interval: TimeInterval, handler: @escaping (AccelerationSample) -> Void) {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 512, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let count = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<count { sum += channelData[0][i] * channelData[0][i] }
            let amplitude = Double(sqrt(sum / Float(count))) * 10
            DispatchQueue.main.async {
                handler(AccelerationSample(x: amplitude, y: 0, z: 0, timestamp: Date()))
            }
        }

        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed: \(error)")
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
