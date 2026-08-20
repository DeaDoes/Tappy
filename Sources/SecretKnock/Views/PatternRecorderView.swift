import SwiftUI

struct PatternRecorderView: View {
    @State private var taps: [Date] = []
    @State private var gapWasTooLong = false
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
                    ForEach(taps.indices, id: \.self) { _ in
                        Circle().frame(width: 12, height: 12)
                    }
                }
            }
            .frame(height: 20)

            Text(gapWasTooLong ? "That pause was too long — started over. Keep the taps closer together."
                               : (taps.count < 3 ? "Knock at least 3 times" : "Looks good"))
                .font(.caption)
                .foregroundStyle(gapWasTooLong ? .orange : .secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Reset") { taps = []; errorMessage = nil }
                    .disabled(taps.isEmpty && errorMessage == nil)
                Button("Save Pattern") { onComplete(KnockPattern(taps: taps)) }
                    .disabled(taps.count < 3)
            }
        }
        .padding()
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: .knockDetected)) { _ in
            // A rejected pattern keeps its taps, so the first knock after an
            // error starts over instead of appending to them.
            if errorMessage != nil { taps = []; errorMessage = nil }
            let now = Date()
            // The matcher gives up after settleDelay, so a pattern containing a
            // longer pause would record perfectly and then never fire. Restart
            // here instead of saving a knock that can't work.
            if let last = taps.last, !KnockDetectionEngine.acceptsGap(now.timeIntervalSince(last)) {
                taps = [now]
                gapWasTooLong = true
                return
            }
            gapWasTooLong = false
            taps.append(now)
        }
    }
}
