import SwiftUI

struct PatternRecorderView: View {
    @State private var taps: [Date] = []
    @State private var gapWasTooLong = false
    @Binding var errorMessage: String?
    let onComplete: (KnockPattern) -> Void
    let onCancel: () -> Void

    private var intervals: [Double] {
        zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) }
    }

    var body: some View {
        SheetScaffold(title: "New Rhythm") {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Knock your rhythm on the table")
                        .font(.largeTitle).bold()
                    Text("Three taps or more, in whatever timing you like. Tappy matches the "
                         + "spacing between them, so an accidental bump won't set it off.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                rhythmStrip

                Text(status)
                    .font(.callout)
                    .foregroundStyle(gapWasTooLong ? .orange : .secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } footer: {
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button("Reset") { taps = []; errorMessage = nil; gapWasTooLong = false }
                .disabled(taps.isEmpty && errorMessage == nil)
            Button("Save Rhythm") { onComplete(KnockPattern(taps: taps)) }
                .buttonStyle(.borderedProminent)
                .disabled(taps.count < 3)
        }
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

    /// The taps laid out along a line, spaced by the real gaps between them —
    /// so what you knocked is visible, not just how many times you knocked.
    private var rhythmStrip: some View {
        HStack(spacing: 0) {
            if taps.isEmpty {
                Text("Knock to start…")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(taps.indices), id: \.self) { i in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                    if i < intervals.count {
                        Rectangle()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: gapWidth(intervals[i]), height: 2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: taps.count)
    }

    // Proportional to the real pause, floored so two fast taps are still
    // legible and capped so the longest allowed pause still fits the sheet.
    private func gapWidth(_ interval: Double) -> CGFloat {
        let fraction = interval / KnockDetectionEngine.maxRecordGap
        return 10 + CGFloat(min(max(fraction, 0), 1)) * 90
    }

    private var status: String {
        if gapWasTooLong {
            return "That pause was too long, so recording started over. Keep the taps closer together."
        }
        if taps.count < 3 { return "Knock at least 3 times — \(taps.count) so far." }
        return "Looks good. Knock more to make it longer, or save it."
    }
}

/// The frame every Tappy sheet uses: a title strip, scrolling content, and a
/// row of buttons pinned to the bottom.
struct SheetScaffold<Content: View, Footer: View>: View {
    let title: String
    var width: CGFloat = 560
    /// Leave nil to fit the content. A fixed height here is what left the
    /// recorder with half a sheet of empty space under its own controls.
    var height: CGFloat? = nil
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(.quaternary.opacity(0.4))

            Divider()

            content()
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 10) {
                Spacer()
                footer()
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(width: width)
        .frame(height: height)
        // Wrapping text reports its real height instead of negotiating it,
        // which is what stops AppKit looping when the sheet sizes itself.
        .fixedSize(horizontal: false, vertical: height == nil)
    }
}
