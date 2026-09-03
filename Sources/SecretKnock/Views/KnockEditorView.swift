import SwiftUI

struct KnockEditorView: View {
    @ObservedObject var config: AppConfig
    var existing: KnockMapping?
    let onDone: () -> Void

    @State private var step: Step
    @State private var pattern: KnockPattern?
    @State private var action: KnockAction?
    @State private var name: String
    @State private var clashMessage: String?

    enum Step { case edit, kind, record, action, name }

    init(config: AppConfig, existing: KnockMapping?, onDone: @escaping () -> Void) {
        self.config = config
        self.existing = existing
        self.onDone = onDone
        _step = State(initialValue: existing == nil ? .kind : .edit)
        _pattern = State(initialValue: existing?.pattern)
        _action = State(initialValue: existing?.action)
        _name = State(initialValue: existing?.name ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .edit:
                editForm
            case .kind:
                kindPicker
            case .record:
                // Caught here, before they spend time picking an app and naming it.
                PatternRecorderView(errorMessage: $clashMessage) { choose($0) }
            case .action:
                ActionPickerView { a in
                    action = a
                    if existing == nil, name.isEmpty { name = defaultName(for: a) }
                    step = existing == nil ? .name : .edit
                }
            case .name:
                VStack(spacing: 16) {
                    Text("Name this knock").font(.headline)
                    TextField("e.g. Open Brave", text: $name).textFieldStyle(.roundedBorder)
                    if let clashMessage { Text(clashMessage).font(.caption).foregroundStyle(.red) }
                    Button("Save") { save() }
                }
                .padding().frame(width: 300)
            }
        }
        // Strip at the top for Cancel; width stays driven by the step content.
        .padding(.top, 28)
        .overlay(alignment: .topTrailing) {
            Button("Cancel") { onDone() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .padding(8)
        }
        // Whole session, not just the recording step: noise could fire a knock mid-setup.
        .onAppear { KnockDetectionEngine.shared.isRecordingMode = true }
        .onDisappear { KnockDetectionEngine.shared.isRecordingMode = false }
    }

    private var kindPicker: some View {
        VStack(spacing: 16) {
            Text("How should this knock work?").font(.headline)

            // The rhythm goes first and gets the prominent button. It is the
            // only option that rejects accidental taps — a fixed count fires on
            // any taps of that number, including hand movements on the palm
            // rest. Leading with the counts taught users to pick the weaker one.
            VStack(spacing: 4) {
                Button {
                    step = .record
                } label: {
                    Text("Record my own rhythm")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Text("Three or more taps in your own timing. Accidental bumps won't match it, so this is the safe choice.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            Text("Or just count taps").font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach([1, 2, 3], id: \.self) { count in
                    Button("\(count) tap\(count == 1 ? "" : "s")") {
                        choose(KnockPattern(fixedCount: count))
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }

            Text("Simpler, but any taps of that number will trigger it — including ones you didn't mean.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let clashMessage {
                Text(clashMessage).font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding().frame(width: 300)
    }

    private func choose(_ p: KnockPattern) {
        if let msg = clashText(for: p) { clashMessage = msg; return }
        clashMessage = nil
        pattern = p
        step = existing == nil ? .action : .edit
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit knock").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opens").font(.caption).foregroundStyle(.secondary)
                    Text(action?.label ?? "Not set")
                }
                Spacer()
                Button("Change") { step = .action }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Knock").font(.caption).foregroundStyle(.secondary)
                    Text(pattern?.summary ?? "Not set")
                }
                Spacer()
                Button("Change") { step = .kind }
            }

            if let clashMessage { Text(clashMessage).font(.caption).foregroundStyle(.red) }
            Divider()
            HStack {
                Spacer()
                Button("Save") { save() }.disabled(pattern == nil || action == nil)
            }
        }
        .padding(20).frame(width: 340)
    }

    private func defaultName(for action: KnockAction) -> String {
        "Open \(action.label)"
    }

    private func clashText(for pattern: KnockPattern) -> String? {
        guard !config.allowSharedRhythm,
              let clash = KnockMatcher.clash(with: pattern, in: config.mappings, excluding: existing?.id)
        else { return nil }
        return "This rhythm is too close to “\(clash.name)”. Re-record a more distinct one, or turn on “Allow shared rhythm” in Settings."
    }

    private func save() {
        guard let pattern, let action else { return }
        // Backstop for the edit flow; new knocks are caught at the record step.
        if let msg = clashText(for: pattern) { clashMessage = msg; return }
        clashMessage = nil
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled knock" : name
        if let existing, let idx = config.mappings.firstIndex(where: { $0.id == existing.id }) {
            config.mappings[idx] = KnockMapping(id: existing.id, name: finalName, pattern: pattern, action: action)
        } else {
            config.mappings.append(KnockMapping(name: finalName, pattern: pattern, action: action))
        }
        onDone()
    }
}
