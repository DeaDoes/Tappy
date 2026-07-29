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

    enum Step { case edit, record, action, name }

    init(config: AppConfig, existing: KnockMapping?, onDone: @escaping () -> Void) {
        self.config = config
        self.existing = existing
        self.onDone = onDone
        _step = State(initialValue: existing == nil ? .record : .edit)
        _pattern = State(initialValue: existing?.pattern)
        _action = State(initialValue: existing?.action)
        _name = State(initialValue: existing?.name ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .edit:
                editForm
            case .record:
                PatternRecorderView(errorMessage: $clashMessage) { p in
                    // Catch a clashing rhythm here, before wasting the user's time
                    // picking an app and naming it.
                    if let msg = clashText(for: p) { clashMessage = msg; return }
                    clashMessage = nil
                    pattern = p
                    step = existing == nil ? .action : .edit
                }
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
        // Reserve a strip at the top for Cancel so it never overlaps the title,
        // while width stays driven by the step content (no stretching Spacer).
        .padding(.top, 28)
        .overlay(alignment: .topTrailing) {
            Button("Cancel") { onDone() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .padding(8)
        }
        // Suppress live matching for the whole editing session, not just the
        // recording screen — otherwise noise could fire a knock mid-setup.
        .onAppear { KnockDetectionEngine.shared.isRecordingMode = true }
        .onDisappear { KnockDetectionEngine.shared.isRecordingMode = false }
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
                    Text("Rhythm").font(.caption).foregroundStyle(.secondary)
                    Text("\(pattern?.tapCount ?? 0) taps")
                }
                Spacer()
                Button("Re-record") { step = .record }
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

    // Unless sharing is on, the message for a rhythm that would also trigger
    // another knock — nil if it's fine to save.
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
