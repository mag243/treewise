import XCTest

/// Open in Terminal stays unavailable while the app is confined, as here,
/// because a shell reaches what the boundary keeps out (ADR 0052).
extension LaunchTests {
    @MainActor
    func testFileMenuOffersNoTerminalWhileConfined() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        XCTAssertFalse(app.menuBarItems["File"].menuItems["Open in Terminal"].isEnabled)
    }

    @MainActor
    func testCommandBarOffersNoTerminalWhileConfined() throws {
        let app = try launchApp()
        let button = app.windows.firstMatch.buttons["Open in Terminal"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: Self.launchTimeout))
        XCTAssertFalse(button.isEnabled)
    }

    @MainActor
    func testContextMenuOffersNoTerminalWhileConfined() throws {
        let app = try launchApp()
        let notes = app.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.waitForExistence(timeout: Self.launchTimeout))
        notes.rightClick()
        let menu = app.tables.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: Self.launchTimeout))
        XCTAssertFalse(menu.menuItems["Open in Terminal"].isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }
}
