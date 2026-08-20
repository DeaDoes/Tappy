import SwiftUI

struct PatternRecorderView: View {
    @State private var taps: [Date] = []
    @Binding var errorMessage: String?
    let onComplete: (KnockPattern) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Knock your secret pattern on the table")
                .font(.headline)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if taps.isEmpty {
                    Text("Knock to start...").foregroundStyle(.secondary).font(.caption)
                } else {
                    ForEach(Array(0..<taps.count), id: \.self) { _ in
                        Circle().frame(width: 12, height: 12)
                    }
                }
            }
            .frame(height: 20)

            Text(taps.count < 3 ? "Knock at least 3 times" : "Looks good")
                .font(.caption).foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Reset") { taps = []; errorMessage = nil }
                    .disabled(taps.isEmpty && errorMessage == nil)
                Button("Save Pattern") {
                    onComplete(KnockPattern(taps: taps))
                }
                .disabled(taps.count < 3)
            }
        }
        .padding()
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: .knockDetected)) { _ in
            // A rejected pattern keeps its taps, so the first knock after an
            // error starts over instead of appending to them.
            if errorMessage != nil { taps = []; errorMessage = nil }
            taps.append(Date())
        }
    }
}
