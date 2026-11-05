import XCTest

/// Favorites the user chooses (ADR 0050).
extension LaunchTests {
    @MainActor
    func testTheContextMenuAddsAFolderToFavorites() throws {
        let app = try launchApp()
        let projects = app.tables.staticTexts["Projects"]
        XCTAssertTrue(projects.waitForExistence(timeout: Self.launchTimeout))
        XCTAssertFalse(app.outlines.staticTexts["Projects"].exists, "not a favorite yet")

        projects.rightClick()
        app.menuItems["Add to Favorites"].click()

        XCTAssertTrue(
            app.outlines.staticTexts["Projects"].waitForExistence(timeout: Self.launchTimeout),
            "the sidebar gets a row")
    }

    @MainActor
    func testTheSidebarRemovesAFavoriteWithoutTouchingTheFolder() throws {
        let app = try launchApp()
        let favorite = app.outlines.staticTexts["Documents"]
        XCTAssertTrue(favorite.waitForExistence(timeout: Self.launchTimeout))

        favorite.rightClick()
        app.menuItems["Remove from Favorites"].click()

        XCTAssertTrue(app.eventually { !favorite.exists }, "the row goes")
        XCTAssertTrue(app.tables.staticTexts["Documents"].exists, "the folder stays")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: try XCTUnwrap(root).appendingPathComponent("Documents").path))
    }

    @MainActor
    func testRestoreBringsBackARemovedFavorite() throws {
        let app = try launchApp()
        let favorite = app.outlines.staticTexts["Documents"]
        XCTAssertTrue(favorite.waitForExistence(timeout: Self.launchTimeout))
        favorite.rightClick()
        app.menuItems["Remove from Favorites"].click()
        XCTAssertTrue(app.eventually { !favorite.exists })

        app.outlines.staticTexts["Favorites"].rightClick()
        app.menuItems["Restore Default Favorites"].click()

        XCTAssertTrue(favorite.waitForExistence(timeout: Self.launchTimeout))
    }
}
