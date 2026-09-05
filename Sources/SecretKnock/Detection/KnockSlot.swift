import Foundation

/// The three tap-count knocks the main screen is built around. They are
/// ordinary fixed-count mappings underneath, so the matcher, the recorder and
/// every saved custom rhythm carry on unchanged.
enum KnockSlot: Int, CaseIterable, Identifiable {
    case single = 1, double = 2, triple = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .single: return "Single Knock"
        case .double: return "Double Knock"
        case .triple: return "Triple Knock"
        }
    }

    var shortTitle: String {
        switch self {
        case .single: return "Single"
        case .double: return "Double"
        case .triple: return "Triple"
        }
    }
}

extension AppConfig {
    /// Mappings the main screen owns — one per slot, keyed by tap count.
    func mapping(for slot: KnockSlot) -> KnockMapping? {
        mappings.first { $0.pattern.isFixedCount && $0.pattern.tapCount == slot.rawValue }
    }

    func action(for slot: KnockSlot) -> KnockAction? { mapping(for: slot)?.action }

    /// nil clears the slot. Replaces in place so the row keeps its position in
    /// the list — reassigning an action shouldn't reshuffle the other knocks.
    func assign(_ action: KnockAction?, to slot: KnockSlot) {
        let index = mappings.firstIndex {
            $0.pattern.isFixedCount && $0.pattern.tapCount == slot.rawValue
        }
        guard let action else {
            if let index { mappings.remove(at: index) }
            return
        }
        let mapping = KnockMapping(
            id: index.map { mappings[$0].id } ?? UUID(),
            name: ActionCatalog.card(for: action).title,
            pattern: KnockPattern(fixedCount: slot.rawValue),
            action: action
        )
        if let index { mappings[index] = mapping } else { mappings.append(mapping) }
    }

    /// Knocks the user recorded a rhythm for. Shown apart from the slots
    /// because they are the only kind an accidental bump cannot trigger.
    var customMappings: [KnockMapping] {
        mappings.filter { !$0.pattern.isFixedCount }
    }

    /// Replaces any rule this app already has for this knock rather than
    /// stacking a second one. Only one can ever run — the matcher takes the
    /// first — so a duplicate is a rule the user made that silently does
    /// nothing, which is never what they meant.
    func setContextRule(_ action: KnockAction, forApp bundleID: String, slot: KnockSlot) {
        contextRules.removeAll { $0.bundleID == bundleID && $0.tapCount == slot.rawValue }
        contextRules.append(ContextRule(bundleID: bundleID, tapCount: slot.rawValue, action: action))
    }

    /// The slot this action is currently assigned to, for the "Current" badge.
    func slot(assigned action: KnockAction) -> KnockSlot? {
        KnockSlot.allCases.first { self.action(for: $0) == action }
    }
}
