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
}
