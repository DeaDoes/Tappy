import SwiftUI

/// Named tap strengths, so nobody has to reason about raw jerk units.
///
/// Measured on real hardware: idle noise peaks around 30, deliberate taps on
/// the case run 800-2800.
///
/// These pick **how firmly you have to tap** — not whether typing gets through.
/// Real typing produces spikes of the same size as taps (median 1181 against
/// 1128), so no preset here can exclude it; the 1s typing gate in
/// `AccelerometerTapDetector` is what does that, at every setting.
enum KnockFeel: String, CaseIterable, Identifiable {
    case light, normal, firm, slap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:  return "Light Tap"
        case .normal: return "Normal Knock"
        case .firm:   return "Firm Knock"
        case .slap:   return "Slap"
        }
    }

    var subtitle: String {
        switch self {
        case .light:  return "The lightest usable tap."
        case .normal: return "Balanced for everyday use."
        case .firm:   return "Requires a firmer knock."
        case .slap:   return "Only strong taps trigger."
        }
    }

    var threshold: Double {
        switch self {
        case .light:  return AccelerometerTapDetector.floor   // 800
        case .normal: return 1200
        case .firm:   return 1800
        case .slap:   return 2600
        }
    }

    var sensitivity: Double { AccelerometerTapDetector.sensitivity(forThreshold: threshold) }
}

extension AppConfig {
    /// The preset matching the current setting, or nil once tuned by hand.
    var knockFeel: KnockFeel? {
        KnockFeel.allCases.first { abs($0.sensitivity - sensitivity) < 0.005 }
    }

    func apply(_ feel: KnockFeel) { sensitivity = feel.sensitivity }
}

struct KnockFeelView: View {
    @ObservedObject var config: AppConfig
    @ObservedObject private var meter = TapMeter.shared

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Knock Feel").font(.subheadline)
            Text("Choose how firmly you want to tap. The trigger mark shows when Tappy will fire.")
                .font(.caption2).foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(KnockFeel.allCases) { presetButton($0) }
            }

            TriggerMeter(level: meter.level)
            HStack {
                Text("Light tap").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $config.sensitivity, in: 0...1)
                Text("Strong knock").font(.caption2).foregroundStyle(.secondary)
            }

            Text("Tap harder than the trigger mark to run your action. "
                 + "Tappy stays quiet while you're typing, so pause a moment before tapping.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func presetButton(_ feel: KnockFeel) -> some View {
        let selected = config.knockFeel == feel
        // No detector restart: the threshold is read live from config on every
        // report. Restarting would blank detection for the 1.5s recalibration,
        // right when the user taps to try the preset out — and calibrate off a
        // machine they are actively touching.
        return Button {
            config.apply(feel)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(feel.title).font(.callout).fontWeight(.medium)
                Text(feel.subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(selected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Live tap strength against the trigger point. Level is reported as a multiple
/// of the current threshold, so 1.0 is exactly the trigger regardless of which
/// preset is active or what the raw units happen to be on this Mac.
struct TriggerMeter: View {
    let level: Double
    private let scale = 2.0

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width
                let fill = min(level / scale, 1.0) * w
                let mark = min(1.0 / scale, 1.0) * w
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level >= 1.0 ? Color.green : Color.accentColor)
                        .frame(width: fill)
                    Rectangle().fill(Color.primary.opacity(0.65))
                        .frame(width: 2).offset(x: mark)
                }
            }
            .frame(height: 10)

            GeometryReader { geo in
                Text("Trigger")
                    .font(.caption2).foregroundStyle(.secondary)
                    .offset(x: min(1.0 / scale, 1.0) * geo.size.width - 18)
            }
            .frame(height: 12)
        }
    }
}
