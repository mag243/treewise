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
            // A trial started can take a free card's place before it is reached.
            guard cardNames(in: list).contains(card) else { continue }
            choose(card, in: list)
            let tryIt = window.buttons["Try for 14 Days"]
            if tryIt.exists {
                press(tryIt, in: window.scrollViews.firstMatch)
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
        hoverFirstCard(in: window, appearance: appearance)
        try dragCardsByHeaderOnly(in: window)
        try reviewCards(in: window, appearance: appearance, startingTrials: true)
        checkCardMenu(in: window)
        open("Templates", in: window)
        let list = window.tables["templatesList"]
        let year = list.textFields.matching(NSPredicate(format: "value == %@", "Household Year"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout), "the templates are listed")
        press(year, in: list)
        let tree = window.outlines["templateTreeEditor"]
        let tax = tree.textFields.matching(NSPredicate(format: "value == %@", "Tax")).firstMatch
        XCTAssertTrue(tax.waitForExistence(timeout: Self.timeout), "its tree shows")
        press(tax, in: tree)
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
            // A trial started can take a free card's place before it is reached.
            guard cardNames(in: list).contains(card) else { continue }
            choose(card, in: list)
            let tryIt = window.buttons["Try for 14 Days"]
            if startingTrials, tryIt.exists {
                press(tryIt, in: window.scrollViews.firstMatch)
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
        // A card's title is a text in it with the card's own name; a long label, as the
        // fields a card recognizes, is matched by value, as a query cannot take it.
        list.groups.allElementsBoundByIndex.filter { group in
            !group.label.isEmpty
                && group.staticTexts.matching(NSPredicate(format: "value == %@", group.label))
                    .firstMatch.exists
        }.map(\.label)
    }

    @MainActor
    func choose(_ card: String, in list: XCUIElement) {
        // The first, so a card shown twice is left to the checks to find, not the walk.
        let title = list.groups[card].firstMatch.staticTexts[card].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: Self.timeout), "\(card) shows")
        press(title, in: list)
        settleScreen()
    }

    /// A right-click on a paid card offers what the card allows (ADR 0105): its order, and
    /// no Turn Off while it is the only add-on that proposes names.
    @MainActor
    private func checkCardMenu(in window: XCUIElement) {
        let list = window.tables.firstMatch
        guard let card = cardNames(in: list).first(where: { $0.hasPrefix("Advanced") }) else {
            return
        }
        press(list.groups[card].firstMatch.staticTexts[card].firstMatch, in: list, .rightClick)
        let menu = list.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: Self.timeout), "the card has a menu")
        // The only add-on that proposes names stays on, so it offers no Turn Off.
        XCTAssertTrue(menu.menuItems["Move Up"].exists, "the card's menu offers its order")
        XCTAssertFalse(menu.menuItems["Turn Off"].exists, "nor a switch it cannot use")
        window.typeKey(.escape, modifierFlags: [])
    }

    /// The pointer on the first card, whose icon then shows the grip (ADR 0106).
    @MainActor
    private func hoverFirstCard(in window: XCUIElement, appearance: String?) {
        let list = window.tables.firstMatch
        guard let card = cardNames(in: list).first else { return }
        press(list.groups[card].firstMatch.staticTexts[card].firstMatch, in: list, .hover)
        settleScreen()
        review(
            window, as: "settings-add-ons-hover", appearance: appearance, isSettingsPane: true)
    }

    /// A card is taken by its header only (ADR 0106): a drag from an open card's body leaves
    /// the order alone, one from its title moves it.
    @MainActor
    private func dragCardsByHeaderOnly(in window: XCUIElement) throws {
        let list = window.tables.firstMatch
        let names = cardNames(in: list)
        guard names.count >= 2, let last = names.last(where: { $0.hasPrefix("Advanced") }),
            let first = names.first, first != last
        else { return }
        choose(last, in: list)
        let card = list.groups[last].firstMatch
        // A text in the body that is not selectable, as its summary is, so a drag there is
        // the list's to start or not.
        let body = card.staticTexts.matching(NSPredicate(format: "value == 'Recognizes'"))
            .firstMatch
        let target = list.groups[first].firstMatch.staticTexts[first].firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: Self.timeout), "the card is open")
        drag(body, onto: target)
        XCTAssertEqual(cardNames(in: list).first, first, "a drag from the body moves nothing")
        drag(card.staticTexts[last].firstMatch, onto: target)
        XCTAssertTrue(
            XCUIApplication().eventually { cardNames(in: list).first == last },
            "a drag from the title moves the card")
    }

    @MainActor
    private func drag(_ source: XCUIElement, onto target: XCUIElement) {
        let centre = CGVector(dx: 0.5, dy: 0.5)
        source.coordinate(withNormalizedOffset: centre).click(
            forDuration: 0.5, thenDragTo: target.coordinate(withNormalizedOffset: centre),
            withVelocity: .slow, thenHoldForDuration: 0.3)
        settleScreen()
    }
}
