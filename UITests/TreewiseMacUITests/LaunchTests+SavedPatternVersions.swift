import XCTest

/// A folder's pattern picked from a saved one: Update from the folder, and a newer version
/// offered with Use It (ADR 0068).
extension LaunchTests {
    private static let savedName = "Folder and Number"
    private static let changedPattern = "{folder} - {seq}"

    @MainActor
    func testAChangedPatternUpdatesTheSavedPatternItWasPickedFrom() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        pickSaved(in: review, app: app)
        usePattern(Self.changedPattern, in: review)
        openPatternMenu(in: review)
        let update = app.menuItems["Update “\(Self.savedName)”"]
        XCTAssertTrue(update.appeared(timeout: Self.launchTimeout), "Update is offered")
        XCTAssertTrue(app.menuItems["Save as New Pattern…"].exists, "and saving it as new")
        update.click()
        openPatternMenu(in: review)
        XCTAssertTrue(
            app.menuItems["Save Pattern…"].appeared(timeout: Self.launchTimeout),
            "an updated pattern is the saved one again")
        XCTAssertFalse(update.exists, "so Update is offered no more")
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testAFolderIsOfferedTheNewerVersionOfItsSavedPatternOnce() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        pickSaved(in: review, app: app)
        review.buttons["Cancel"].firstMatch.click()
        changeSavedPatternInSettings(app: app)

        let again = try reopenReview(of: Self.oddName, in: app)
        let notice = again.staticTexts["“\(Self.savedName)” has a newer version:"]
        XCTAssertTrue(notice.appeared(timeout: Self.launchTimeout), "the newer is offered")
        let useIt = again.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'Use It'")
        ).firstMatch
        XCTAssertTrue(useIt.exists, "with Use It")
        useIt.click()
        XCTAssertTrue(app.eventually { !notice.exists }, "taken, it is offered no more")
    }

    /// Opens the add-ons header and the pattern menu of the free module.
    @MainActor
    private func openPatternMenu(in review: XCUIElement) {
        let header = review.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add-ons'"))
            .firstMatch
        XCTAssertTrue(header.appeared(timeout: Self.launchTimeout), "the header shows")
        if header.label.hasPrefix("Add-ons:") { header.click() }
        let menu = review.buttons.matching(
            NSPredicate(format: "label IN {'Saved Patterns', 'Choose a Saved Pattern'}")
        ).firstMatch
        XCTAssertTrue(menu.appeared(timeout: Self.launchTimeout), "the menu shows")
        menu.click()
    }

    @MainActor
    private func pickSaved(in review: XCUIElement, app: XCUIApplication) {
        openPatternMenu(in: review)
        let saved = app.menuItems.matching(
            NSPredicate(format: "title BEGINSWITH %@", Self.savedName)
        ).firstMatch
        XCTAssertTrue(saved.appeared(timeout: Self.launchTimeout), "it lists the pattern")
        saved.click()
    }

    /// Gives the saved pattern another text in Settings, committed with Return.
    @MainActor
    private func changeSavedPatternInSettings(app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let names = settings.toolbars.buttons["Names"]
        XCTAssertTrue(names.appeared(timeout: Self.launchTimeout))
        names.click()
        let saved = settings.staticTexts[Self.savedName]
        XCTAssertTrue(saved.appeared(timeout: Self.launchTimeout))
        saved.click()
        let field = settings.textFields["Pattern"]
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "its pattern shows")
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(Self.changedPattern + "\r")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.eventually { !settings.exists }, "Settings closes")
    }

    /// Opens the overview again from the folder the browser shows.
    @MainActor
    private func reopenReview(of file: String, in app: XCUIApplication) throws -> XCUIElement {
        let row = app.tables.staticTexts[file]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout), "the folder shows")
        row.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.appeared(timeout: Self.launchTimeout), "the overview opens")
        return review
    }
}
