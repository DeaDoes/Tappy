import SwiftUI

struct KnockEditorView: View {
    @ObservedObject var config: AppConfig
    var existing: KnockMapping?
    let onDone: () -> Void

    @State private var step: Step
    @State private var pattern: KnockPattern?
    @State private var action: KnockAction?
    @State private var name: String

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
        VStack {
            switch step {
            case .edit:
                editForm
            case .record:
                PatternRecorderView { p in
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
                    Button("Save") { save() }
                }
                .padding().frame(width: 300)
            }
        }
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
                    Text(action.map(actionLabel) ?? "Not set")
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

            Divider()
            HStack {
                Spacer()
                Button("Save") { save() }.disabled(pattern == nil || action == nil)
            }
        }
        .padding(20).frame(width: 340)
    }

    private func defaultName(for action: KnockAction) -> String {
        "Open \(actionLabel(action))"
    }

    private func actionLabel(_ action: KnockAction) -> String {
        switch action {
        case .openApp(let id): return id.components(separatedBy: ".").last ?? id
        case .openFile(let url): return url.lastPathComponent
        case .openURL(let url): return url.host ?? url.absoluteString
        }
    }

    private func save() {
        guard let pattern, let action else { return }
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled knock" : name
        if let existing, let idx = config.mappings.firstIndex(where: { $0.id == existing.id }) {
            config.mappings[idx] = KnockMapping(id: existing.id, name: finalName, pattern: pattern, action: action)
        } else {
            config.mappings.append(KnockMapping(name: finalName, pattern: pattern, action: action))
        }
        onDone()
    }
}
