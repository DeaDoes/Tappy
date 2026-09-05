import XCTest
@testable import SecretKnock

final class ActionCatalogTests: IsolatedConfigTestCase {
    /// The fallback exists for actions the user configured themselves. A
    /// built-in reaching it means a card was dropped from the catalog and the
    /// library would show it as "Unknown".
    func testEveryCatalogActionResolvesBackToItsOwnCard() {
        for card in ActionCatalog.all {
            guard let action = card.action else { continue }
            XCTAssertEqual(ActionCatalog.card(for: action).title, card.title)
        }
    }

    func testCatalogActionsSurviveEncodingAndDecoding() throws {
        for card in ActionCatalog.all {
            guard let action = card.action else { continue }
            let data = try JSONEncoder().encode(action)
            XCTAssertEqual(try JSONDecoder().decode(KnockAction.self, from: data), action)
        }
    }

    /// Keystroke actions need Accessibility; opening things and drawing over
    /// the screen must not ask for it.
    func testOnlyKeystrokeActionsAskForAccessibility() {
        XCTAssertTrue(KnockAction.copy.needsAccessibility)
        XCTAssertTrue(KnockAction.spotlight.needsAccessibility)
        XCTAssertFalse(KnockAction.openApp(bundleID: "com.apple.finder").needsAccessibility)
        XCTAssertFalse(KnockAction.screenFlash.needsAccessibility)
        XCTAssertFalse(KnockAction.volumeUp.needsAccessibility)
    }

    func testTemplateActionsAreTheOnlyOnesNeedingConfiguration() {
        XCTAssertTrue(KnockAction.runShortcut(name: "").needsConfiguration)
        XCTAssertTrue(KnockAction.openApp(bundleID: "").needsConfiguration)
        XCTAssertFalse(KnockAction.runShortcut(name: "Focus").needsConfiguration)
        XCTAssertFalse(KnockAction.copy.needsConfiguration)
    }

    func testAssigningASlotReplacesInPlaceAndClearingRemovesIt() {
        config.assign(.copy, to: .double)
        XCTAssertEqual(config.action(for: .double), .copy)
        XCTAssertEqual(config.mappings.count, 1)
        XCTAssertEqual(config.mappings[0].pattern.tapCount, 2)
        XCTAssertTrue(config.mappings[0].pattern.isFixedCount)

        let id = config.mappings[0].id
        config.assign(.paste, to: .double)
        XCTAssertEqual(config.mappings.count, 1)
        XCTAssertEqual(config.mappings[0].id, id, "reassigning should not create a second mapping")
        XCTAssertEqual(config.action(for: .double), .paste)

        config.assign(nil, to: .double)
        XCTAssertNil(config.action(for: .double))
        XCTAssertTrue(config.mappings.isEmpty)
    }

    /// The slots are fixed-count mappings, so a recorded rhythm must not show
    /// up as one of them — the main screen would claim a knock it doesn't own.
    func testRecordedRhythmsAreNotMistakenForSlots() {
        config.mappings = [KnockMapping(name: "Secret",
                                        pattern: KnockPattern(intervals: [200, 400]),
                                        action: .screenFlash)]
        XCTAssertNil(config.action(for: .triple))
        XCTAssertEqual(config.customMappings.count, 1)
    }
}
