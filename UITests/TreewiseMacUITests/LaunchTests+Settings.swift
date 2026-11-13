import XCTest

/// The Settings window fits its contents, in two tabs.
extension LaunchTests {
    static let settingsWindow = "TreewiseSettings"

    @MainActor
    func testSettingsFitsItsContentsWithoutAScrollBar() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        XCTAssertTrue(
            settings.checkBoxes["Show hidden files"].appeared(timeout: Self.launchTimeout))
        XCTAssertFalse(settings.scrollBars.firstMatch.exists)
    }

    @MainActor
    func testSettingsKeepsTheNamePatternsInATabOfTheirOwn() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let names = settings.toolbars.buttons["Names"]
        XCTAssertTrue(
            names.appeared(timeout: Self.launchTimeout), "Settings has a Names tab")
        names.click()
        XCTAssertTrue(
            settings.staticTexts["Name Patterns"].appeared(timeout: Self.launchTimeout),
            "the saved patterns are there (ADR 0068)")
    }

    @MainActor
    func testSettingsListsTheAddOnsWithWhatTheyRead() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let tab = settings.toolbars.buttons["Add-ons"]
        XCTAssertTrue(
            tab.appeared(timeout: Self.launchTimeout), "Settings has an Add-ons tab")
        tab.click()
        XCTAssertTrue(
            settings.staticTexts["Folder Pattern"].appeared(timeout: Self.launchTimeout),
            "the free add-on is listed")
        XCTAssertFalse(
            settings.switches["Folder Pattern"].exists || settings.staticTexts["Always on"].exists,
            "the only add-on offers no on or off: it stays on (ADR 0070, ADR 0092)")
        XCTAssertTrue(
            settings.staticTexts.matching(
                NSPredicate(format: "value BEGINSWITH 'Reads names only'")
            ).firstMatch.exists, "it says what it reads")
        XCTAssertTrue(
            settings.staticTexts["Recognizes"].exists,
            "the first card is selected and open (ADR 0092)")
        XCTAssertFalse(
            settings.switches["On in new folders"].exists
                || settings.staticTexts["Always on in new folders"].exists,
            "the only add-on offers no choice for new folders")
        XCTAssertFalse(settings.scrollBars.firstMatch.exists, "the add-ons fit")
        XCTAssertFalse(
            settings.switches["Also read names in the same folder a year before"].exists
                || settings.staticTexts["Also read names in the same folder a year before"].exists,
            "no add-on here reads the year before, so the choice is not offered (ADR 0090)")
    }

    /// The legend's kinds stay side by side, also when a setting lays the cards out again.
    @MainActor
    func testTheLegendKeepsItsKindsTogether() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let tab = settings.toolbars.buttons["Add-ons"]
        XCTAssertTrue(tab.appeared(timeout: Self.launchTimeout))
        tab.click()
        let dates = settings.staticTexts["Dates"]
        let series = settings.staticTexts["Series"]
        XCTAssertTrue(dates.appeared(timeout: Self.launchTimeout), "the open card has a legend")
        let together: CGFloat = 40
        XCTAssertLessThan(series.frame.minX - dates.frame.maxX, together, "side by side")
        let yearBefore = settings.switches["Also read names in the same folder a year before"]
        guard yearBefore.exists else { return }
        for _ in 0..<2 {
            let value = yearBefore.value as? Int
            yearBefore.click()
            XCTAssertTrue(app.eventually { yearBefore.value as? Int != value })
            XCTAssertLessThan(
                series.frame.minX - dates.frame.maxX, together,
                "still side by side after the cards are laid out again")
        }
    }

    /// Needs two add-ons, as the official build has with Advanced Folder Pattern not tried.
    @MainActor
    func testSettingsOpensTheAddOnCardSelected() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let tab = settings.toolbars.buttons["Add-ons"]
        XCTAssertTrue(tab.appeared(timeout: Self.launchTimeout))
        tab.click()
        XCTAssertTrue(
            settings.staticTexts["Folder Pattern"].appeared(timeout: Self.launchTimeout))
        let advanced = settings.staticTexts["Advanced Folder Pattern"]
        try XCTSkipUnless(advanced.exists, "the open build has one add-on")
        let recognizes = settings.staticTexts.matching(identifier: "Recognizes")
        let tryIt = settings.buttons["Try for 14 Days"]
        XCTAssertEqual(recognizes.count, 1, "the first card is open, and only that one")
        XCTAssertFalse(tryIt.exists, "the second card is folded")
        advanced.click()
        XCTAssertTrue(tryIt.appeared(timeout: Self.launchTimeout), "the card selected opens")
        XCTAssertEqual(recognizes.count, 1, "the card before folds")
    }

    @MainActor
    func testSettingsKeepsItsSizeFromTabToTab() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        XCTAssertTrue(
            settings.checkBoxes["Show hidden files"].appeared(timeout: Self.launchTimeout),
            "Settings opens at General")
        let size = settings.frame.size
        XCTAssertGreaterThanOrEqual(size.width, 600, "room for long names")
        for tab in ["Names", "Add-ons", "General"] {
            settings.toolbars.buttons[tab].click()
            XCTAssertEqual(settings.frame.size, size, "\(tab) keeps the window's size")
        }
    }

    @MainActor
    func testSettingsIsTitledByTheChosenTab() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        XCTAssertTrue(
            settings.checkBoxes["Show hidden files"].appeared(timeout: Self.launchTimeout))
        XCTAssertEqual(settings.title, "General", "Settings opens at General")
        for tab in ["Names", "Add-ons", "General"] {
            settings.toolbars.buttons[tab].click()
            XCTAssertTrue(app.eventually { settings.title == tab }, "the window is titled \(tab)")
        }
    }

    @MainActor
    func testANamePatternIsChosenInTheListAndEditedBelow() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let names = settings.toolbars.buttons["Names"]
        XCTAssertTrue(names.appeared(timeout: Self.launchTimeout))
        names.click()
        let example = settings.staticTexts["Folder and Number"]
        XCTAssertTrue(
            example.appeared(timeout: Self.launchTimeout), "the list shows its names")
        example.click()
        let name = settings.textFields["Name"]
        XCTAssertTrue(
            app.eventually { name.value as? String == "Folder and Number" },
            "the chosen one's name is edited below")
        settings.buttons["Add Pattern"].click()
        XCTAssertTrue(
            app.eventually { name.value as? String == "New Pattern" }, "a new one is chosen at once"
        )
    }
}
