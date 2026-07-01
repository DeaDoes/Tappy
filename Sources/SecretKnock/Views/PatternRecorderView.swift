import SwiftUI

struct PatternRecorderView: View {
    @State private var recorder = KnockRecorder()
    @State private var tapCount = 0
    @Binding var errorMessage: String?
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

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Reset") { recorder.reset(); tapCount = 0; errorMessage = nil }
                    .disabled(tapCount == 0 && errorMessage == nil)
                Button("Save Pattern") {
                    onComplete(recorder.finish())
                }
                .disabled(tapCount < 3)
            }
        }
        .padding()
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: .knockDetected)) { _ in
            // First tap of a fresh attempt clears the previous clash warning.
            if tapCount == 0 { errorMessage = nil }
            recorder.recordTap()
            tapCount += 1
        }
    }
}
