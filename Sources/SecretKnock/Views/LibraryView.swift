import SwiftUI

/// Everything Tappy can do, browsable, with one control deciding which knock a
/// click assigns to.
struct LibraryView: View {
    @ObservedObject var config: AppConfig
    @State private var target: KnockSlot = .single

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Action Library").font(.largeTitle).bold()
                    Text("Browse everything Tappy can do when you knock.")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text("Assign to").foregroundStyle(.secondary)
                    Picker("Assign to", selection: $target) {
                        ForEach(KnockSlot.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .frame(maxWidth: 380)
                }

                ActionSections(columns: 3, tileHeight: 130, showsSubtitle: false) { action in
                    badge(for: action)
                } onSelect: { action in
                    config.assign(action, to: target)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "Current" when it's on the knock you're assigning to, otherwise the name
    /// of the knock that already has it — so you can see a conflict before you
    /// create one.
    private func badge(for action: KnockAction?) -> ActionTile.Badge? {
        guard let action, let assigned = config.slot(assigned: action) else { return nil }
        return .init(text: assigned == target ? "Current" : assigned.shortTitle)
    }
}
