import SwiftUI

/// Recording a knock with its own rhythm. Fixed-count knocks are the three
/// slots on the main screen now, so this flow is only ever about a rhythm:
/// record it, pick what it does, name it.
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
        Group {
            switch step {
            case .action:
                // Full-size sheet of its own; it brings its own Cancel.
                ActionPickerSheet(title: name.isEmpty ? "New knock" : name,
                                  current: action,
                                  subtitle: "For this rhythm. Click a card to assign.") { picked in
                    action = picked
                    if let picked, existing == nil, name.isEmpty { name = defaultName(for: picked) }
                    step = existing == nil ? .name : .edit
                } onCancel: {
                    step = existing == nil ? .record : .edit
                }

            default:
                compactStep
            }
        }
        // Whole session, not just the recording step: noise could fire a knock mid-setup.
        .onAppear { KnockDetectionEngine.shared.isRecordingMode = true }
        .onDisappear { KnockDetectionEngine.shared.isRecordingMode = false }
    }

    @ViewBuilder private var compactStep: some View {
        switch step {
        case .record:
            // Caught here, before they spend time picking an action and naming it.
            PatternRecorderView(errorMessage: $clashMessage, onComplete: { choose($0) },
                                onCancel: onDone)

        case .name:
            SheetScaffold(title: "New Rhythm") {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name this knock").font(.largeTitle).bold()
                        Text("So you can tell it apart from your other rhythms.")
                            .foregroundStyle(.secondary)
                    }
                    TextField("e.g. Open Brave", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                    if let clashMessage {
                        Text(clashMessage).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } footer: {
                Button("Cancel", action: onDone).keyboardShortcut(.cancelAction)
                Button("Save") { save() }.buttonStyle(.borderedProminent)
            }

        default:
            editForm
        }
    }

    private var editForm: some View {
        SheetScaffold(title: name.isEmpty ? "Edit Knock" : name) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Edit knock").font(.largeTitle).bold()

                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME").font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                }

                row("DOES", value: action.map { ActionCatalog.card(for: $0).title } ?? "Not set",
                    button: "Change") { step = .action }

                row("KNOCK", value: pattern?.summary ?? "Not set",
                    button: "Re-record") { step = .record }

                if let clashMessage {
                    Text(clashMessage).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } footer: {
            Button("Cancel", action: onDone).keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(pattern == nil || action == nil)
        }
    }

    private func row(_ label: String, value: String, button: String,
                     action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(value).font(.body)
            }
            Spacer()
            Button(button, action: action)
        }
        .padding(14)
        .background(Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func choose(_ p: KnockPattern) {
        if let msg = clashText(for: p) { clashMessage = msg; return }
        clashMessage = nil
        pattern = p
        step = existing == nil ? .action : .edit
    }

    private func defaultName(for action: KnockAction) -> String {
        ActionCatalog.card(for: action).title
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
