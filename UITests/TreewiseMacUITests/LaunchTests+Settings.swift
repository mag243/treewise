import XCTest

/// The Settings window fits its contents, in two tabs.
extension LaunchTests {
    private static let settingsWindow = "com_apple_SwiftUI_Settings_window"

    @MainActor
    func testSettingsFitsItsContentsWithoutAScrollBar() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        // Settings opens at the tab chosen last, which another test may have changed.
        let general = settings.toolbars.buttons["General"]
        XCTAssertTrue(general.waitForExistence(timeout: Self.launchTimeout))
        general.click()
        XCTAssertTrue(
            settings.staticTexts["Show hidden files"].waitForExistence(timeout: Self.launchTimeout))
        XCTAssertFalse(settings.scrollBars.firstMatch.exists)
    }

    @MainActor
    func testSettingsKeepsTheNamePatternsInATabOfTheirOwn() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let names = settings.toolbars.buttons["Names"]
        XCTAssertTrue(
            names.waitForExistence(timeout: Self.launchTimeout), "Settings has a Names tab")
        names.click()
        XCTAssertTrue(
            settings.staticTexts["Name Patterns"].waitForExistence(timeout: Self.launchTimeout),
            "the saved patterns are there (ADR 0068)")
    }

    @MainActor
    func testSettingsListsTheAddOnsWithWhatTheyRead() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let tab = settings.toolbars.buttons["Add-ons"]
        XCTAssertTrue(
            tab.waitForExistence(timeout: Self.launchTimeout), "Settings has an Add-ons tab")
        tab.click()
        let free = settings.checkBoxes["Folder Pattern"]
        XCTAssertTrue(
            free.waitForExistence(timeout: Self.launchTimeout), "the free add-on is listed")
        XCTAssertFalse(free.isEnabled, "the last add-on that is on stays on (ADR 0070)")
        XCTAssertTrue(settings.staticTexts["Reads names only"].exists, "it says what it reads")
        XCTAssertFalse(
            settings.scrollBars.firstMatch.exists,
            "the tab is measured with its add-ons, not before they load")
    }
}
