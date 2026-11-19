import XCTest

/// Selecting several items with the mouse, as in Finder: ⌘-click adds a row to the selection.
extension LaunchTests {
    @MainActor
    func testCommandClickAddsARowToTheSelection() throws {
        let app = try launchApp()
        let table = app.tables.firstMatch
        let notes = table.staticTexts["Notes.md"]
        let documents = table.staticTexts["Documents"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))

        notes.click()
        XCUIElement.perform(withKeyModifiers: .command) { documents.click() }

        let selected = table.tableRows.matching(NSPredicate(format: "isSelected == true"))
        XCTAssertEqual(selected.count, 2, "⌘-click adds Documents to Notes.md")
    }

    @MainActor
    func testCommandClickAddsAnIconToTheSelection() throws {
        let app = try launchApp()
        XCTAssertTrue(app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey("1", modifierFlags: .command)
        let grid = app.collectionViews.firstMatch
        let notes = grid.staticTexts["Notes.md"]
        let documents = grid.staticTexts["Documents"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))

        notes.click()
        XCUIElement.perform(withKeyModifiers: .command) { documents.click() }

        // The grid's tiles do not report their selection to the tests; the status bar does.
        let status = app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH '2 of '"))
        XCTAssertTrue(
            status.firstMatch.appeared(timeout: Self.launchTimeout),
            "⌘-click adds Documents to Notes.md")
    }
}
