import Foundation

struct KnockMapping: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var pattern: KnockPattern
    var action: KnockAction
}
