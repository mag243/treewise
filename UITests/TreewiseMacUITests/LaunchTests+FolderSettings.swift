import XCTest

/// Clearing folder settings asks first (ADR 0072).
extension LaunchTests {
    @MainActor
    func testClearFolderSettingsAsksFirst() throws {
        let app = try launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let names = settings.toolbars.buttons["Names"]
        XCTAssertTrue(names.waitForExistence(timeout: Self.launchTimeout))
        names.click()
        let clear = settings.buttons["Clear Folder Settings…"]
        XCTAssertTrue(clear.waitForExistence(timeout: Self.launchTimeout), "the button shows")
        clear.click()
        let confirm = app.buttons["Clear Folder Settings"]
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.launchTimeout), "it asks first")
        // The app keeps folder settings in the user's own folder, so the test only cancels.
        app.buttons["Cancel"].click()
        XCTAssertTrue(
            confirm.waitForNonExistence(timeout: Self.launchTimeout),
            "cancelling closes the question")
    }
}
