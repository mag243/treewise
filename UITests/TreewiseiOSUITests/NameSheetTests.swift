import XCTest

/// The sheet that asks for a name (ADR 0130): New Folder asks first and Cancel makes
/// nothing; a rename can take the add-ons' proposals.
final class NameSheetTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func openDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testCancellingNewFolderMakesNoFolder() {
        let app = openDocuments()
        app.buttons["New Folder"].firstMatch.tap()
        let sheet = app.navigationBars["New Folder"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(app.textFields["name"].value as? String, "untitled folder")

        sheet.buttons["Cancel"].tap()

        XCTAssertTrue(app.eventually { !sheet.exists })
        XCTAssertFalse(row("untitled folder", in: app).exists, "nothing was made")
    }

    @MainActor
    func testNewFolderIsMadeWithTheNameTyped() {
        let app = openDocuments()
        app.buttons["New Folder"].firstMatch.tap()
        let sheet = app.navigationBars["New Folder"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout))
        // The name is selected whole, so typing replaces it.
        app.textFields["name"].typeText("Receipts")

        sheet.buttons["Create"].tap()

        XCTAssertTrue(row("Receipts", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(row("untitled folder", in: app).exists)
    }

    @MainActor
    func testRenameWithSuggestionsPutsAProposalInTheField() {
        let app = openDocuments()
        row("Notes.md", in: app).press(forDuration: 1)
        app.buttons["Rename with Suggestions…"].firstMatch.tap()
        let suggestion = app.buttons["suggestion-0"]
        XCTAssertTrue(
            suggestion.waitForExistence(timeout: Self.timeout), "a proposal from the default")
        let proposed = suggestion.label

        suggestion.tap()
        let field = app.textFields["name"]
        XCTAssertEqual(field.value as? String, proposed)
        // The caret is after the proposal, nothing selected: typing adds to it.
        field.typeText("x")
        XCTAssertEqual(field.value as? String, proposed + "x")
        field.typeText(XCUIKeyboardKey.delete.rawValue)
        app.navigationBars["Rename"].buttons["Rename"].tap()

        XCTAssertTrue(row(proposed, in: app).waitForExistence(timeout: Self.timeout), "renamed")
    }

    @MainActor
    func testRenameIsGreyedWhileTheNameIsUnchanged() {
        let app = openDocuments()
        row("Notes.md", in: app).press(forDuration: 1)
        app.buttons["Rename"].firstMatch.tap()
        let rename = app.navigationBars["Rename"].buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(rename.isEnabled, "nothing to rename yet")

        app.textFields["name"].typeText("Ideas")

        XCTAssertTrue(rename.isEnabled, "a new name can be given")
    }

    @MainActor
    func testRenameWithSuggestionsStartsWithTheFirstProposalAndOffersTheCurrentName() {
        let app = openDocuments()
        row("Notes.md", in: app).press(forDuration: 1)
        app.buttons["Rename with Suggestions…"].firstMatch.tap()
        let suggestion = app.buttons["suggestion-0"]
        XCTAssertTrue(
            suggestion.waitForExistence(timeout: Self.timeout), "a proposal from the default")
        let proposed = suggestion.label
        let field = app.textFields["name"]
        XCTAssertTrue(
            app.eventually { field.value as? String == proposed }, "the first proposal is taken")

        let current = app.buttons["currentName"]
        XCTAssertTrue(current.exists, "the current name is offered")
        current.tap()
        XCTAssertEqual(field.value as? String, "Notes.md", "back to the current name")
        suggestion.tap()
        app.navigationBars["Rename"].buttons["Rename"].tap()

        XCTAssertTrue(row(proposed, in: app).waitForExistence(timeout: Self.timeout), "renamed")
    }

    @MainActor
    func testRenameRightAfterTakingAProposalGivesTheFileThatName() {
        let app = openDocuments()
        row("Notes.md", in: app).press(forDuration: 1)
        app.buttons["Rename with Suggestions…"].firstMatch.tap()
        let suggestion = app.buttons["suggestion-0"]
        XCTAssertTrue(
            suggestion.waitForExistence(timeout: Self.timeout), "a proposal from the default")
        let proposed = suggestion.label

        suggestion.tap()
        app.navigationBars["Rename"].buttons["Rename"].tap()

        XCTAssertTrue(row(proposed, in: app).waitForExistence(timeout: Self.timeout), "renamed")
        XCTAssertFalse(row("Notes.md", in: app).exists, "the old name is gone")
    }
}
