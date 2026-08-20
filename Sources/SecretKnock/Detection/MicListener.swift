import AVFoundation

// Reads the mic and emits a "knock score" per audio buffer. Only a sudden
// impulse against a quiet background scores high, so sustained sound (talking,
// music) is rejected. It can't tell a knock from a clap — the rhythm does that.
class MicListener {
    private let audioEngine = AVAudioEngine()
    private var baseline: Float = 0.0001   // slow-moving background loudness
    private var startTime = Date()
    private var lpf: Float = 0             // low-pass state, carries across buffers

    // Both tunable per mic and desk.
    private let onsetRatioMin: Float = 3.0 // knock must be 3x louder than background
    // One-pole LPF, ~0.15 ≈ a few-hundred-Hz cutoff at 44.1kHz. A knock is a
    // low thud, a clap is sharp and broadband. Raise toward 1.0 if real knocks
    // feel muffled; lower if claps still trigger.
    private let lpfAlpha: Float = 0.15

    func start(handler: @escaping (Double) -> Void) {
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
            for i in 0..<count {
                self.lpf += self.lpfAlpha * (channel[0][i] - self.lpf)
                energy += self.lpf * self.lpf
            }
            let rms = (energy / Float(count)).squareRoot()

            let onset = rms / (self.baseline + 1e-6)            // how sudden vs background
            self.baseline = self.baseline * 0.97 + rms * 0.03   // update slowly

            AudioMeter.shared.report(Double(rms) * 10)          // raw, ungated

            // Skip the first moments while baseline settles, or quiet ambient
            // reads as a spike against a near-zero background.
            let warming = Date().timeIntervalSince(self.startTime) < 0.6
            let score = (!warming && onset > self.onsetRatioMin) ? Double(rms) * 10 : 0

            DispatchQueue.main.async { handler(score) }
        }

        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed: \(error)")
        }
    }
}
