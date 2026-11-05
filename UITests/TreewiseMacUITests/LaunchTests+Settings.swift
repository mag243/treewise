import XCTest

/// The Settings window fits its contents.
extension LaunchTests {
    private static let settingsWindow = "com_apple_SwiftUI_Settings_window"

    @MainActor
    func testSettingsFitsItsContentsWithoutAScrollBar() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        XCTAssertTrue(
            settings.staticTexts["Show hidden files"].waitForExistence(timeout: Self.launchTimeout))
        XCTAssertFalse(settings.scrollBars.firstMatch.exists)
    }
}
