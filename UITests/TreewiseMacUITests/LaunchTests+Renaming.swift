import XCTest

/// Renaming with a click on the selected name (ADR 0039).
extension LaunchTests {
    /// How far into the name's field the click lands: on the first letters.
    private static let nameStart: CGFloat = 0.1

    @MainActor
    func testClickingTheSelectedNameRenamesIt() throws {
        let app = try launchApp()
        let documents = app.tables.staticTexts["Documents"]
        XCTAssertTrue(documents.waitForExistence(timeout: Self.launchTimeout))
        // Selected with the keyboard, so the click on the name is a single click.
        app.tables.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).click()
        app.typeKey(.downArrow, modifierFlags: [])
        // On the word itself: the name's field runs on to the end of the column,
        // and a click on its empty part does not rename.
        documents.coordinate(withNormalizedOffset: CGVector(dx: Self.nameStart, dy: 0.5)).click()
        // Once the double-click interval passes the name is in a text field.
        let field = app.tables.textFields.firstMatch
        XCTAssertTrue(
            field.waitForExistence(timeout: Self.launchTimeout),
            "a click on the selected name starts renaming it")
        app.typeText("Papers\r")
        let root = try XCTUnwrap(root)
        let renamed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                FileManager.default.fileExists(atPath: root.appendingPathComponent("Papers").path)
            }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [renamed], timeout: Self.launchTimeout), .completed,
            "Return renames the folder")
    }
}
