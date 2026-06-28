import SwiftUI

struct PatternRecorderView: View {
    @State private var recorder = KnockRecorder()
    @State private var tapCount = 0
    let onComplete: (KnockPattern) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Knock your secret pattern on the table")
                .font(.headline)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if tapCount == 0 {
                    Text("Knock to start...").foregroundStyle(.secondary).font(.caption)
                } else {
                    ForEach(Array(0..<tapCount), id: \.self) { _ in
                        Circle().frame(width: 12, height: 12)
                    }
                }
            }
            .frame(height: 20)

            Text(tapCount < 3 ? "Knock at least 3 times" : "Looks good")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("Reset") { recorder.reset(); tapCount = 0 }
                    .disabled(tapCount == 0)
                Button("Save Pattern") {
                    onComplete(recorder.finish())
                }
                .disabled(tapCount < 3)
            }
        }
        .padding()
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: .knockDetected)) { _ in
            recorder.recordTap()
            tapCount += 1
        }
    }
}
