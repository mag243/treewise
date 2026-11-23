import XCTest

/// Move to ▸ and Copy to ▸ in an item's context menu (ADR 0147): the favorites, and the
/// folder items were last moved or copied into at the top.
extension LaunchTests {
    @MainActor
    func testCopyToAndMoveToSendToAFavoriteAndThenOfferItFirst() throws {
        let app = try launchApp()
        let root = try XCTUnwrap(root)
        let notes = app.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))

        notes.rightClick()
        app.tables.menus.submenuItem("Documents", in: "Copy to").firstMatch.click()
        let copied = root.appendingPathComponent("Documents/Notes.md").path
        XCTAssertTrue(
            app.eventually { FileManager.default.fileExists(atPath: copied) },
            "copied into the favorite")

        app.tables.staticTexts["Projects"].rightClick()
        let moveTo = app.tables.menus.menuItems["Move to"]
        XCTAssertTrue(moveTo.waitForExistence(timeout: Self.launchTimeout), "the menu opens")
        moveTo.hover()
        let documents = moveTo.menuItems.matching(identifier: "Documents")
        XCTAssertTrue(
            app.eventually { documents.count == 2 }, "a recent target and a favorite")
        documents.element(boundBy: 0).click()

        let moved = root.appendingPathComponent("Documents/Projects").path
        XCTAssertTrue(
            app.eventually { FileManager.default.fileExists(atPath: moved) },
            "moved into the folder copied to before")
    }
}
