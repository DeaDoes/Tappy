import Foundation

enum KnockAction: Codable, Equatable {
    case openApp(bundleID: String)
    case openFile(URL)
    case openURL(URL)

    var label: String {
        switch self {
        case .openApp(let id): return id.components(separatedBy: ".").last ?? id
        case .openFile(let url): return url.lastPathComponent
        case .openURL(let url): return url.host ?? url.absoluteString
        }
    }
}
