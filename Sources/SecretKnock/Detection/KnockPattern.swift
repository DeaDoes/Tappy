import Foundation

struct KnockPattern: Codable, Equatable {
    let intervals: [Double] // milliseconds between consecutive taps
    var tapCount: Int { intervals.count + 1 }
}
