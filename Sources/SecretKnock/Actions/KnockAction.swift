import Foundation

enum KnockAction: Codable, Equatable {
    case openApp(bundleID: String)
    case openFile(URL)
    case openURL(URL)
}
