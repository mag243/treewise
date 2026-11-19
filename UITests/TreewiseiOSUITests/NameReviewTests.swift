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
}
