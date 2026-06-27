import SwiftUI

struct KnockEditorView: View {
    @ObservedObject var config: AppConfig
    var existing: KnockMapping?
    let onDone: () -> Void

    @State private var step: Step = .record
    @State private var pattern: KnockPattern?
    @State private var action: KnockAction?
    @State private var name: String = ""

    enum Step { case record, action, name }

    var body: some View {
        VStack {
            switch step {
            case .record:
                PatternRecorderView(config: config) { p in
                    pattern = p
                    step = .action
                }
            case .action:
                ActionPickerView { a in
                    action = a
                    name = existing?.name ?? ""
                    step = .name
                }
            case .name:
                VStack(spacing: 16) {
                    Text("Name this knock").font(.headline)
                    TextField("e.g. Open Brave", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") { save() }
                }
                .padding()
                .frame(width: 300)
            }
        }
        // Suppress matching/actions for the whole time the editor is open,
        // and guarantee it's turned back on when the editor closes.
        .onAppear { KnockDetectionEngine.shared.isRecordingMode = true }
        .onDisappear { KnockDetectionEngine.shared.isRecordingMode = false }
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
