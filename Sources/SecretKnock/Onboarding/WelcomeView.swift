import SwiftUI

/// The walkthrough's six screens.
///
/// House style is short second-person copy and one decision per screen. The two
/// tap steps have no Continue button at all: the only way past them is a real
/// knock, or the small Skip that every step carries.
struct WelcomeView: View {
    @ObservedObject var controller: WelcomeController
    @ObservedObject private var meter = TapMeter.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 28) {
                Spacer()
                content
                Spacer()
                dots
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)

            Button("Skip") { controller.finish() }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .padding(20)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.step {
        case .intro:        intro
        case .tapCheck:     tapCheck
        case .permission:   permission
        case .pickAction:   pickAction
        case .doItForReal:  doItForReal
        case .menuBar:      menuBar
        }
    }

    // MARK: - steps

    private var intro: some View {
        step(
            title: "Your Mac is the button.",
            body: "Knock on the case and Tappy runs whatever you tell it to. "
                + "This takes about a minute, and ends with a knock that actually works."
        ) {
            Button("Start") { controller.advance() }.buttonStyle(.borderedProminent)
        }
    }

    /// Proves the sensor works before anything has been asked of the user.
    /// Detection needs no permission, so this deliberately comes first — they
    /// see it work, then get asked.
    private var tapCheck: some View {
        step(
            title: controller.isUsingTrackpad ? "Click your trackpad." : "Tap the case.",
            body: controller.isUsingTrackpad
                ? "This Mac has no motion sensor Tappy can read, so it counts trackpad clicks instead. "
                    + "Everything else works the same."
                : "Anywhere on the chassis — the side, the palm rest, the closed lid. Give it a knock."
        ) {
            VStack(spacing: 14) {
                TapLevelBar(level: meter.level)

                if controller.taps > 0 {
                    Text(controller.taps == 1 ? "Nice knock. Again?" : "That's it — you've got it.")
                        .foregroundStyle(.secondary)
                } else if controller.isTyping && !controller.isUsingTrackpad {
                    // Without this the 1s typing gate looks like a dead app.
                    Text("Paused while you type.").foregroundStyle(.orange)
                } else {
                    Text("Waiting for a tap…").foregroundStyle(.tertiary)
                }

                if controller.taps >= 2 {
                    Button("Continue") { controller.advance() }.buttonStyle(.borderedProminent)
                }
            }
        }
    }

    /// The one permission the walkthrough needs, asked where its purpose is
    /// visible — one screen before the knock that uses it.
    private var permission: some View {
        step(
            title: "Let Tappy press keys for you.",
            body: "Detection already works — you just saw it. This is only so a knock can "
                + "press a shortcut for you, the way the next step will."
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: controller.accessibilityGranted
                          ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(controller.accessibilityGranted ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility").font(.headline)
                        Text(controller.accessibilityGranted
                             ? "Allowed. Knocks can run actions."
                             : "Not allowed yet.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    if !controller.accessibilityGranted {
                        Button("Allow…") { controller.requestAccessibility() }
                    }
                    // Always enabled: a walkthrough that traps someone who said
                    // no is worse than one that ends on a screen flash.
                    Button(controller.accessibilityGranted ? "Continue" : "Not now") {
                        controller.advance()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var pickAction: some View {
        let action = welcomeAction(accessibilityGranted: controller.accessibilityGranted)
        let card = ActionCatalog.card(for: action)
        return step(
            title: "Three taps takes a screenshot.",
            body: controller.accessibilityGranted
                ? "That's your first knock. You can change it, or add more, whenever you like."
                : "Without Accessibility a knock can't press keys, so this one flashes the screen "
                    + "instead. Still real — still yours to change later."
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: card.symbol)
                    Text(card.title).font(.headline)
                    Spacer()
                    Text(welcomeSlot.title).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

                Button("Save it") { controller.advance() }.buttonStyle(.borderedProminent)
            }
        }
    }

    /// The real thing: detection is handed back to the engine, the mapping is
    /// saved, and three taps run the ordinary path all the way to the action.
    private var doItForReal: some View {
        step(
            title: controller.demoFired ? "That was real." : "Now do it. Tap three times.",
            body: controller.demoFired
                ? (controller.accessibilityGranted
                   ? "A screenshot just landed on your Desktop. Nothing about that was a demo — "
                     + "that's the knock you saved, doing its job."
                   : "That flash was your knock firing for real. Turn on Accessibility later and "
                     + "it can press keys too.")
                : "Three taps on the case, at whatever pace feels natural."
        ) {
            VStack(spacing: 14) {
                TapProgressDots(count: controller.taps, of: welcomeSlot.rawValue)

                if controller.demoFired {
                    Button("Continue") { controller.advance() }.buttonStyle(.borderedProminent)
                } else if let missed = controller.missedCount {
                    // Exact counts only, so four taps matches nothing and fires
                    // nothing. Saying which way they missed beats a silent reset.
                    Text(missed > welcomeSlot.rawValue
                         ? "That was \(missed) taps. Try exactly three."
                         : "Only \(missed). Give it three.")
                        .foregroundStyle(.orange)
                } else {
                    Text("\(controller.taps) of \(welcomeSlot.rawValue)")
                        .foregroundStyle(.tertiary).monospacedDigit()
                }
            }
        }
    }

    private var menuBar: some View {
        step(
            title: "It lives in the menu bar.",
            body: "Tappy has no Dock icon — look for it up top. Everything else is in there, "
                + "including this walkthrough if you want to run it again."
        ) {
            VStack(spacing: 14) {
                Image(systemName: "arrow.up").font(.system(size: 30, weight: .light))
                Button("Done") { controller.finish() }.buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - scaffolding

    private func step<Extra: View>(
        title: String, body: String, @ViewBuilder extra: () -> Extra
    ) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.system(size: 34, weight: .bold)).multilineTextAlignment(.center)
            Text(body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            extra().padding(.top, 8)
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(WelcomeStep.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s == controller.step ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

/// The live tap level, as a multiple of the trigger point — 1.0 is exactly hard
/// enough. Unit-free on purpose, so it reads the same at every sensitivity.
struct TapLevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(level >= 1 ? Color.green : Color.accentColor)
                    .frame(width: geo.size.width * min(level, 1.2) / 1.2)
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: 8)
        .frame(maxWidth: 320)
    }
}

struct TapProgressDots: View {
    let count: Int
    let of: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<of, id: \.self) { i in
                Circle()
                    .fill(i < count ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 16, height: 16)
                    .animation(.spring(duration: 0.25), value: count)
            }
        }
    }
}
