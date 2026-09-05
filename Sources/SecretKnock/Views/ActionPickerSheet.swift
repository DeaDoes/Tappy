import SwiftUI

/// "Choose an action" — the full catalog, for one knock.
struct ActionPickerSheet: View {
    let title: String
    let current: KnockAction?
    var subtitle: String? = nil
    /// Non-nil when the sheet also has to ask which knock — the app-rule flow,
    /// where the slot isn't decided before the sheet opens.
    var slot: Binding<KnockSlot>? = nil
    let onPick: (KnockAction?) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(.quaternary.opacity(0.4))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose an action").font(.largeTitle).bold()
                        Text(subtitle ?? "For \(title.lowercased()). Click a card to assign.")
                            .foregroundStyle(.secondary)
                    }

                    if let slot {
                        Picker("Knock", selection: slot) {
                            ForEach(KnockSlot.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 380)
                    }

                    ActionSections(columns: 2, tileHeight: 150) { action in
                        action == current ? .init(text: "Current") : nil
                    } onSelect: { action in
                        onPick(action)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(width: 760, height: 620)
    }
}
