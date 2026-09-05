import XCTest
@testable import SecretKnock

/// Base class for tests that need an `AppConfig`.
///
/// `AppConfig` saves on every change, so a test touching `AppConfig.shared`
/// wrote straight into the real defaults, over the knocks the person using this
/// Mac had saved — recoverable only if the test also restored them, and not at
/// all if it failed partway. Each test gets its own defaults suite instead,
/// removed afterwards, so tests can also run alongside each other.
class IsolatedConfigTestCase: XCTestCase {
    private(set) var config: AppConfig!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "tappy.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("could not open the test defaults suite")
        }
        config = AppConfig(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        config = nil
        suiteName = nil
        super.tearDown()
    }
}
