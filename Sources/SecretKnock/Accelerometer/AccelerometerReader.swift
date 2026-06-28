import AVFoundation

// Reads the mic and emits a "knock score" per audio buffer. Only a sudden
// impulse against a quiet background scores high, so sustained sounds (talking,
// music) are rejected. It can't tell a knock from a clap — that's what the
// multi-tap rhythm is for.
class AccelerometerReader: AccelerometerReaderProtocol {
    private let audioEngine = AVAudioEngine()
    private var baseline: Float = 0.0001   // slow-moving background loudness
    private var startTime = Date()

    // ponytail: calibration knob for the physical world — tune per mic/desk.
    private let onsetRatioMin: Float = 3.0 // a knock must be 3x louder than background

    func start(interval: TimeInterval, handler: @escaping (AccelerationSample) -> Void) {
        startTime = Date()
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            print("No usable audio input")
            return
        }

        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }

            var energy: Float = 0
            for i in 0..<count { energy += channel[0][i] * channel[0][i] }
            let rms = (energy / Float(count)).squareRoot()

            let onset = rms / (self.baseline + 1e-6)            // how sudden vs background
            self.baseline = self.baseline * 0.97 + rms * 0.03   // update slowly

            // Live level for the tuning meter (raw, ungated).
            AudioMeter.shared.report(Double(rms) * 10)

            // Only a sudden impulse counts; sustained sound won't out-pace baseline.
            // Skip the first moments so baseline settles, or quiet ambient reads
            // as a "spike" against a near-zero background.
            let warming = Date().timeIntervalSince(self.startTime) < 0.6
            let score = (!warming && onset > self.onsetRatioMin) ? Double(rms) * 10 : 0

            DispatchQueue.main.async {
                handler(AccelerationSample(x: score, y: 0, z: 0, timestamp: Date()))
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
