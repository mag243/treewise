import XCTest

/// The menu bar's menus stay whole while the windows change (ADR 0080).
extension LaunchTests {
    /// The items of `menu` whose title starts with `prefix`, such as "Undo Rename".
    @MainActor
    private func items(of menu: XCUIElement, startingWith prefix: String) -> XCUIElementQuery {
        menu.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", prefix))
    }

    /// Opens the Edit menu, checks that Undo and Redo are in it once each, and closes it.
    @MainActor
    private func assertEditMenuIsWhole(in app: XCUIApplication, _ message: String) {
        let edit = app.menuBars.menuBarItems["Edit"]
        edit.click()
        XCTAssertTrue(edit.menuItems.firstMatch.appeared(timeout: Self.launchTimeout), message)
        XCTAssertEqual(items(of: edit, startingWith: "Undo").count, 1, message)
        XCTAssertEqual(items(of: edit, startingWith: "Redo").count, 1, message)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testChangingTheFolderWhileTheEditMenuIsOpenKeepsTreewiseRunning() throws {
        let root = try XCTUnwrap(self.root)
        let app = try launchApp()
        let window = app.windows.firstMatch
        let notes = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        notes.click()

        app.menuBars.menuBarItems["Edit"].click()
        // The selected file goes and another comes while the menu is open,
        // which changes what the menu's items act on.
        try FileManager.default.removeItem(at: root.appendingPathComponent("Notes.md"))
        try Data("fresh".utf8).write(to: root.appendingPathComponent("Fresh.md"))
        let fresh = window.tables.staticTexts["Fresh.md"]
        _ = fresh.appeared(timeout: Self.launchTimeout)
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertEqual(app.state, .runningForeground, "Treewise keeps running")
        XCTAssertTrue(fresh.appeared(timeout: Self.launchTimeout), "the list follows the folder")
        assertEditMenuIsWhole(in: app, "the Edit menu is whole")
    }

    @MainActor
    func testTheEditMenuOutlivesWindowsOpeningAndClosing() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.windows.firstMatch.tables.staticTexts["Notes.md"].appeared(
                timeout: Self.launchTimeout))
        assertEditMenuIsWhole(in: app, "at launch")

        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        XCTAssertTrue(settings.appeared(timeout: Self.launchTimeout), "Settings opens")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.disappeared(timeout: Self.launchTimeout), "Settings closes")
        assertEditMenuIsWhole(in: app, "after Settings")

        XCTAssertTrue(app.waitForNewTab())
        app.typeKey("t", modifierFlags: .command)
        XCTAssertTrue(app.waitForSecondTab(), "a tab opens")
        assertEditMenuIsWhole(in: app, "with a second tab")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.eventually { app.tabGroups.firstMatch.tabs.count < 2 }, "it closes")

        openWindowBeside(in: app)
        assertEditMenuIsWhole(in: app, "with a window beside")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.eventually { app.windows.count == 1 }, "the window beside closes")
        assertEditMenuIsWhole(in: app, "after a window closed")
    }
}
