import XCTest

/// The UI review's walk through Settings (ADR 0103): `tools/build.sh uireview settings`.
extension UIReviewTests {
    private static let tabs = ["General", "Names", "Templates", "Add-ons"]

    /// Starts each paid add-on's trial from its card in Settings, as the user does, and
    /// closes Settings again: the walks that show what an add-on adds need it working.
    @MainActor
    func startTrials(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows[Self.settingsWindow]
        XCTAssertTrue(window.waitForExistence(timeout: Self.timeout), "Settings opens")
        open("Add-ons", in: window)
        let list = window.tables.firstMatch
        XCTAssertTrue(list.groups.firstMatch.waitForExistence(timeout: Self.timeout), "cards show")
        for card in cardNames(in: list) {
            choose(card, in: list)
            let tryIt = window.buttons["Try for 14 Days"]
            if tryIt.exists {
                tryIt.click()
                settleScreen()
            }
        }
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(window.waitForNonExistence(timeout: Self.timeout), "Settings closes")
    }

    @MainActor
    func testSettings() throws {
        try eachAppearance(settings)
    }

    /// Every tab of Settings; every add-on card open in turn and back to the first, then
    /// each paid one's trial started from its card; and the Templates tab with the add-on.
    @MainActor
    private func settings(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows[Self.settingsWindow]
        XCTAssertTrue(window.waitForExistence(timeout: Self.timeout), "Settings opens")
        for tab in Self.tabs {
            open(tab, in: window)
            review(
                window, as: "settings-\(slug(tab))", appearance: appearance, isSettingsPane: true)
        }
        try reviewCards(in: window, appearance: appearance, startingTrials: false)
        try reviewCards(in: window, appearance: appearance, startingTrials: true)
        open("Templates", in: window)
        let list = window.tables["templatesList"]
        let year = list.textFields.matching(NSPredicate(format: "value == %@", "Household Year"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout), "the templates are listed")
        year.click()
        let tree = window.outlines["templateTreeEditor"]
        let tax = tree.textFields.matching(NSPredicate(format: "value == %@", "Tax")).firstMatch
        XCTAssertTrue(tax.waitForExistence(timeout: Self.timeout), "its tree shows")
        tax.click()
        settleScreen()
        review(
            window, as: "settings-templates-trial", appearance: appearance, isSettingsPane: true)
    }

    /// Opens each card of the Add-ons tab in turn, and the first again after the last.
    /// `startingTrials` starts each paid add-on's trial from its card, as the user does.
    @MainActor
    private func reviewCards(in window: XCUIElement, appearance: String?, startingTrials: Bool)
        throws
    {
        open("Add-ons", in: window)
        // Each card is a group named after its add-on.
        let list = window.tables.firstMatch
        XCTAssertTrue(list.groups.firstMatch.waitForExistence(timeout: Self.timeout), "cards show")
        let name = startingTrials ? "settings-add-ons-trial" : "settings-add-ons"
        for card in cardNames(in: list) {
            choose(card, in: list)
            let tryIt = window.buttons["Try for 14 Days"]
            if startingTrials, tryIt.exists {
                tryIt.click()
                settleScreen()
            }
            review(
                window, as: "\(name)-\(slug(card))", appearance: appearance,
                isSettingsPane: true)
        }
        // Back to the first card there is now: a trial can take a free card's place.
        if let first = cardNames(in: list).first {
            choose(first, in: list)
            review(
                window, as: "\(name)-\(slug(first))-again", appearance: appearance,
                isSettingsPane: true)
        }
    }

    /// The cards of the list, each a group named after its add-on.
    @MainActor
    func cardNames(in list: XCUIElement) -> [String] {
        list.groups.allElementsBoundByIndex
            .filter { !$0.label.isEmpty && $0.staticTexts[$0.label].exists }.map(\.label)
    }

    @MainActor
    func choose(_ card: String, in list: XCUIElement) {
        let title = list.groups[card].staticTexts[card]
        XCTAssertTrue(title.waitForExistence(timeout: Self.timeout), "\(card) shows")
        title.click()
        settleScreen()
    }
}
