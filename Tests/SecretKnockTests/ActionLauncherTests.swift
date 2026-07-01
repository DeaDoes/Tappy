import XCTest
@testable import SecretKnock

final class ActionLauncherTests: XCTestCase {
    func test_open_url_stores_url() {
        let action = KnockAction.openURL(URL(string: "https://apple.com")!)
        if case .openURL(let url) = action {
            XCTAssertEqual(url.host, "apple.com")
        } else { XCTFail() }
    }

    func test_open_file_stores_path() {
        let url = URL(fileURLWithPath: "/Users/test/notes.txt")
        let action = KnockAction.openFile(url)
        if case .openFile(let fileURL) = action {
            XCTAssertEqual(fileURL.path, "/Users/test/notes.txt")
        } else { XCTFail() }
    }

    func test_url_normalization() {
        XCTAssertEqual(ActionPickerView.normalizedURL("example.com")?.scheme, "https")
        XCTAssertEqual(ActionPickerView.normalizedURL("https://example.com")?.scheme, "https")
        XCTAssertEqual(ActionPickerView.normalizedURL("mailto:a@b.com")?.scheme, "mailto")
        XCTAssertNil(ActionPickerView.normalizedURL("   "))
    }

    func test_codable_round_trip() throws {
        let action = KnockAction.openURL(URL(string: "https://example.com")!)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(KnockAction.self, from: data)
        XCTAssertEqual(action, decoded)
    }
}
