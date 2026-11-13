import XCTest

/// AppKit brings back every window and tab after a quit, whatever the system
/// setting says (ADR 0083).
extension LaunchTests {
    @MainActor
    func testQuittingAndStartingAgainBringsBackEveryTab() throws {
        let root = try XCTUnwrap(root)
        let rootName = try rootName
        // Keeping the windows, as a person starts Treewise; XCUITest ignores the saved
        // state unless told, which also keeps it from being saved.
        let app = XCUIApplication()
        app.launchArguments =
            ["-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "NO"]
            + OpenedLog.arguments(for: root)
        app.launch()
        XCTAssertTrue(app.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        XCTAssertTrue(app.waitForNewTab())
        app.typeKey("t", modifierFlags: .command)
        XCTAssertTrue(app.waitForSecondTab())
        let tab = app.windows.firstMatch
        XCTAssertTrue(tab.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        tab.tables.staticTexts["Projects"].doubleClick()
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(timeout: Self.launchTimeout))
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout), "Treewise quits")

        app.launch()
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(timeout: Self.launchTimeout),
            "the tab on Projects comes back")
        XCTAssertTrue(
            app.eventually { app.tabGroups.firstMatch.tabs.count == 2 },
            "beside the tab on \(rootName)")

        // No windows are kept for the next launch, so no test starts with these.
        XCTAssertTrue(
            app.eventually {
                let window = app.windows.firstMatch
                if window.exists { app.typeKey("w", modifierFlags: .command) }
                return !window.exists
            }, "every window closes")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout))
    }
}
