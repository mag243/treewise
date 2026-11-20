import XCTest

/// The name overview on the iPad, with the free module only (ADR 0129).
final class NameReviewTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testASuggestedNameIsApprovedRenamedAndUndone() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        let notes = row("Notes.md", in: app)
        XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))

        notes.press(forDuration: 1)
        app.buttons["Suggest Names…"].firstMatch.tap()
        let proposal = app.textFields["proposal-Notes.md"].firstMatch
        XCTAssertTrue(
            proposal.waitForExistence(timeout: Self.timeout), "the overview shows the file")
        XCTAssertTrue(
            app.eventually {
                !((proposal.value as? String) ?? "").isEmpty
                    && (proposal.value as? String) != proposal.placeholderValue
            },
            "a name is proposed from the default pattern")
        let proposed = (proposal.value as? String) ?? ""

        app.buttons["approve-Notes.md"].firstMatch.tap()
        app.navigationBars.buttons["Rename"].tap()

        XCTAssertTrue(row(proposed, in: app).waitForExistence(timeout: Self.timeout), "renamed")
        XCTAssertFalse(notes.exists)
        app.buttons["undo"].firstMatch.tap()
        XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout), "undone")
    }

    /// The whole folder's overview from the View menu, also where no empty space is left below
    /// the rows for the folder's own menu.
    @MainActor
    func testTheViewMenuSuggestsNamesForTheWholeFolder() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

        app.buttons["viewMenu"].firstMatch.tap()
        app.buttons["Suggest Names for Whole Folder…"].firstMatch.tap()
        XCTAssertTrue(
            app.textFields["proposal-Notes.md"].firstMatch.waitForExistence(
                timeout: Self.timeout),
            "the overview shows the folder's files")
        XCTAssertTrue(app.textFields["proposal-Budget.txt"].firstMatch.exists)
    }

    /// Opens the overview of Notes.md, with its proposal read. The app opens at the first
    /// location, Documents, so this works in portrait too, where the sidebar hides.
    @MainActor
    private func openOverview() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        let notes = row("Notes.md", in: app)
        XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))
        notes.press(forDuration: 1)
        app.buttons["Suggest Names…"].firstMatch.tap()
        XCTAssertTrue(
            app.textFields["proposal-Notes.md"].firstMatch.waitForExistence(
                timeout: Self.timeout), "the overview shows the file")
        return app
    }

    /// In landscape the panel about the chosen file shows beside the list, as on the Mac,
    /// and Hide Preview takes it away.
    @MainActor
    func testThePanelAboutTheFileShowsBesideTheListAndHides() {
        let app = openOverview()
        let panel = app.descendants(matching: .any)["nameDetails"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: Self.timeout), "beside the list")
        XCTAssertTrue(
            app.staticTexts["In This Folder"].firstMatch.exists, "with the names around it")
        app.buttons["Hide Preview"].firstMatch.tap()
        XCTAssertTrue(app.eventually { !panel.exists }, "hidden")
        XCTAssertTrue(app.buttons["Show Preview"].firstMatch.exists)
    }

    /// Save Pattern… keeps the pattern under a name, which the menu then offers.
    @MainActor
    func testAPatternIsSavedUnderANameFromTheMenu() {
        let app = openOverview()
        let menu = app.buttons["Choose a Saved Pattern"].firstMatch
        menu.tap()
        app.buttons["Save Pattern…"].firstMatch.tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout), "a name is asked")
        name.typeText("Notes Pattern")
        app.alerts.buttons["Save"].tap()

        menu.tap()
        XCTAssertTrue(
            app.buttons["Notes Pattern"].firstMatch.waitForExistence(timeout: Self.timeout),
            "the menu offers it")
    }

    /// In portrait there is no room beside the list: a row's ⓘ shows the panel in a sheet.
    @MainActor
    func testARowsInfoShowsThePanelWhereItIsNotBesideTheList() {
        XCUIDevice.shared.orientation = .portrait
        let app = openOverview()
        let panel = app.descendants(matching: .any)["nameDetails"].firstMatch
        XCTAssertFalse(panel.exists, "not beside the list")
        app.buttons["About Notes.md"].firstMatch.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: Self.timeout), "in a sheet")
        XCTAssertTrue(app.staticTexts["In This Folder"].firstMatch.exists)
    }
}
