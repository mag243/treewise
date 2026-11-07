import XCTest

/// Clearing folder settings, which asks first (ADR 0072). The app keeps the folder settings
/// of a UI test apart from the user's, so the test may clear them.
extension LaunchTests {
    private static let typedPattern = "Trip {seq}"

    @MainActor
    func testClearingFolderSettingsForgetsTheFoldersPattern() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        usePattern(Self.typedPattern, in: review)
        XCTAssertTrue(
            proposal(beginningWith: "Trip ", in: review).waitForExistence(
                timeout: Self.launchTimeout), "the typed pattern proposes the name")
        review.buttons["Cancel"].firstMatch.click()

        clearFolderSettings(in: app)

        let row = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(row.waitForExistence(timeout: Self.launchTimeout), "the folder shows")
        row.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()
        let again = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(
            proposal(containing: "Holiday - Lighthouse", in: again).waitForExistence(
                timeout: Self.launchTimeout), "the folder's own pattern is recognized again")
        XCTAssertFalse(proposal(beginningWith: "Trip ", in: again).exists, "the typed one is gone")
    }

    /// Clears the folder settings in Settings > Names: Cancel first, then Clear.
    @MainActor
    private func clearFolderSettings(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let names = settings.toolbars.buttons["Names"]
        XCTAssertTrue(names.waitForExistence(timeout: Self.launchTimeout))
        names.click()
        let clear = settings.buttons["Clear Folder Settings…"]
        XCTAssertTrue(clear.waitForExistence(timeout: Self.launchTimeout), "the button shows")
        clear.click()
        let confirm = app.buttons["Clear Folder Settings"]
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.launchTimeout), "it asks first")
        app.buttons["Cancel"].click()
        XCTAssertTrue(
            confirm.waitForNonExistence(timeout: Self.launchTimeout), "Cancel closes the question")
        clear.click()
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.launchTimeout))
        confirm.click()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: Self.launchTimeout), "it is cleared")
        settings.typeKey("w", modifierFlags: .command)
    }

    @MainActor
    private func proposal(beginningWith start: String, in review: XCUIElement) -> XCUIElement {
        review.textFields.matching(NSPredicate(format: "value BEGINSWITH %@", start)).firstMatch
    }

    @MainActor
    private func proposal(containing text: String, in review: XCUIElement) -> XCUIElement {
        review.textFields.matching(NSPredicate(format: "value CONTAINS %@", text)).firstMatch
    }
}
