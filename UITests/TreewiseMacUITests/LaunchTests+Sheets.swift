import XCTest

/// A window that shows a sheet takes no new tab and is not put beside
/// another until the sheet is answered, as on every Mac; a new tab then
/// crashed Treewise. A new window of its own still opens.
extension LaunchTests {
    @MainActor
    func testCommandTWhileASheetShowsKeepsTreewiseRunning() throws {
        let app = try launchWithRefusal()
        app.typeKey("t", modifierFlags: .command)
        try expectRunningWithTheSheet(app)
    }

    @MainActor
    func testCommandNWhileASheetShowsOpensAWindowOfItsOwn() throws {
        let app = try launchWithRefusal()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(
            app.windows.element(boundBy: 1).waitForExistence(timeout: Self.launchTimeout),
            "a new window opens, as on every Mac")
        XCTAssertTrue(app.sheets.firstMatch.exists, "and the sheet still waits for an answer")
    }

    @MainActor
    func testWindowBesideWhileASheetShowsKeepsTreewiseRunning() throws {
        let app = try launchWithRefusal()
        app.typeKey("n", modifierFlags: [.command, .option])
        try expectRunningWithTheSheet(app)
    }

    /// Starts Treewise and types a folder that does not exist in the address
    /// bar, so the window shows the sheet that refuses it.
    @MainActor
    private func launchWithRefusal() throws -> XCUIApplication {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        app.typeKey("l", modifierFlags: .command)
        XCTAssertTrue(app.textFields["Address"].waitForExistence(timeout: Self.launchTimeout))
        app.typeKey("a", modifierFlags: .command)
        for key in "nowhere/" { app.typeKey(String(key), modifierFlags: []) }
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.sheets.firstMatch.waitForExistence(timeout: Self.launchTimeout),
            "a path that names no folder is refused in a sheet")
        return app
    }

    @MainActor
    private func expectRunningWithTheSheet(_ app: XCUIApplication) throws {
        XCTAssertTrue(
            app.sheets.firstMatch.waitForExistence(timeout: Self.launchTimeout),
            "the sheet still waits for an answer")
        XCTAssertEqual(app.state, .runningForeground, "and Treewise keeps running")
        XCTAssertEqual(app.windows.count, 1, "without a new tab or window")
    }
}
