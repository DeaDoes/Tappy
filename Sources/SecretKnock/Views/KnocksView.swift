import AppKit
import SwiftUI

struct KnocksView: View {
    @ObservedObject var config: AppConfig
    let onOpenLibrary: () -> Void

    @State private var editingSlot: KnockSlot?
    @State private var newRuleBundleID: String?
    @State private var newRuleSlot: KnockSlot = .double
    @State private var editingRhythm: KnockMapping?
    @State private var showRhythmEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                yourKnocks
                contextAwareCard
                customRhythms
                suggested
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $editingSlot) { slot in
            ActionPickerSheet(title: slot.title, current: config.action(for: slot)) { action in
                config.assign(action, to: slot)
                editingSlot = nil
            } onCancel: { editingSlot = nil }
        }
        .sheet(item: Binding(get: { newRuleBundleID.map(BundleBox.init) },
                             set: { newRuleBundleID = $0?.id })) { box in
            ActionPickerSheet(
                title: KnockAction.appName(forBundleID: box.id) ?? box.id,
                current: nil,
                subtitle: "Runs only while this app is in front.",
                slot: $newRuleSlot
            ) { action in
                if let action {
                    config.setContextRule(action, forApp: box.id, slot: newRuleSlot)
                }
                newRuleBundleID = nil
            } onCancel: { newRuleBundleID = nil }
        }
        .sheet(isPresented: $showRhythmEditor) {
            KnockEditorView(config: config, existing: editingRhythm) { showRhythmEditor = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What should your Mac do when you knock?")
                .font(.largeTitle).bold()
            Text("Assign actions to Single, Double, and Triple Knock.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - The three slots

    private var yourKnocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Knocks").font(.title3).bold()

            // A grid, not a horizontal scroller: inside a NavigationSplitView
            // detail column a horizontal ScrollView lays its content out from
            // the window's left edge, which puts the first card under the
            // sidebar. Three cards wrap fine, and nothing ends up off-screen.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)],
                      alignment: .leading, spacing: 16) {
                ForEach(KnockSlot.allCases) { slot in
                    ActionTile(card: card(for: slot),
                               eyebrow: slot.title,
                               height: 210,
                               trailing: testButton(for: slot)) {
                        editingSlot = slot
                    }
                }
            }
        }
    }

    private func card(for slot: KnockSlot) -> ActionCard {
        guard let action = config.action(for: slot) else {
            return ActionCard(title: "Not set",
                              subtitle: "Click to choose what this knock does.",
                              symbol: "plus", tint: .gray, action: nil)
        }
        return ActionCatalog.card(for: action)
    }

    private func testButton(for slot: KnockSlot) -> AnyView? {
        guard let action = config.action(for: slot) else { return nil }
        return AnyView(TilePillButton(title: "Test") { ActionLauncher.launch(action) })
    }

    // MARK: - Context-aware gestures

    private var contextAwareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Context-Aware Gestures").font(.headline)
                    Text("Use different knock actions when a specific app is active.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $config.contextAwareGestures)
                    .toggleStyle(.switch).labelsHidden()
                    .accessibilityLabel("Context-Aware Gestures")
            }
            .padding(16)
            .background(Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if config.contextAwareGestures {
                ForEach(config.contextRules) { rule in
                    ruleRow(rule)
                }
                Button {
                    if let bundleID = chooseAppBundleID() { newRuleBundleID = bundleID }
                } label: {
                    Label("Add app rule", systemImage: "plus")
                }
            }
        }
    }

    private func ruleRow(_ rule: ContextRule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ActionCatalog.card(for: rule.action).symbol)
                .foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(KnockAction.appName(forBundleID: rule.bundleID) ?? rule.bundleID)
                    .font(.subheadline).fontWeight(.medium)
                Text("\(rule.slot?.title ?? "\(rule.tapCount) taps") → \(rule.action.label)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                config.contextRules.removeAll { $0.id == rule.id }
            } label: { Image(systemName: "trash") }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete rule for \(rule.bundleID)")
        }
        .padding(12)
        .background(Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func chooseAppBundleID() -> String? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    // MARK: - Recorded rhythms

    // Kept alongside the three slots: a fixed count fires on any taps of that
    // number, including accidental ones, so a recorded rhythm is still the only
    // knock a bump on the desk can't trigger.
    private var customRhythms: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Rhythms").font(.title3).bold()
                Spacer()
                Button {
                    editingRhythm = nil
                    showRhythmEditor = true
                } label: { Label("Record a rhythm", systemImage: "plus") }
            }

            if config.customMappings.isEmpty {
                Text("Record your own timing for a knock that accidental bumps can't match.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)],
                          alignment: .leading, spacing: 14) {
                    ForEach(config.customMappings) { mapping in
                        ActionTile(card: rhythmCard(mapping),
                                   eyebrow: mapping.pattern.summary,
                                   height: 150,
                                   trailing: AnyView(
                                       TilePillButton(title: "Test") {
                                           ActionLauncher.launch(mapping.action)
                                       })) {
                            editingRhythm = mapping
                            showRhythmEditor = true
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                config.mappings.removeAll { $0.id == mapping.id }
                            }
                        }
                    }
                }
            }
        }
    }

    private func rhythmCard(_ mapping: KnockMapping) -> ActionCard {
        let base = ActionCatalog.card(for: mapping.action)
        return ActionCard(title: mapping.name, subtitle: base.title,
                          symbol: base.symbol, tint: base.tint, action: mapping.action)
    }

    // MARK: - Suggestions

    private var suggested: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested Actions").font(.title3).bold()
                Text("Open the Library to assign actions.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)],
                      alignment: .leading, spacing: 14) {
                ForEach(ActionCatalog.cards(in: .essentials)) { card in
                    ActionTile(card: card, height: 120, showsSubtitle: false) { onOpenLibrary() }
                }
            }
        }
    }
}

/// `.sheet(item:)` needs an Identifiable; a bundle ID string on its own isn't.
private struct BundleBox: Identifiable {
    let id: String
}
