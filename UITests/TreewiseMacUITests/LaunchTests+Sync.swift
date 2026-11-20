import XCTest

/// Settings > General's switch for syncing through the cloud drives (ADR 0144): on by
/// default, and off once turned off when Settings opens again. A UI test's settings live in
/// memory; that they are kept is the package tests' (`BrowserSettingsSyncTests`).
extension LaunchTests {
    @MainActor
    func testSyncingIsOnAndStaysOffOnceTurnedOff() throws {
        let app = try launchApp()
        let syncs = generalSyncSwitch(in: app)
        XCTAssertEqual(syncs.value as? Int, 1, "on by default")
        syncs.click()
        XCTAssertEqual(syncs.value as? Int, 0)
        app.windows[Self.settingsWindow].typeKey("w", modifierFlags: .command)

        XCTAssertEqual(generalSyncSwitch(in: app).value as? Int, 0, "still off")
    }

    /// The switch in Settings > General, which opens first.
    @MainActor
    private func generalSyncSwitch(in app: XCUIApplication) -> XCUIElement {
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let syncs = settings.checkBoxes["Sync settings through cloud drives"]
        XCTAssertTrue(syncs.appeared(timeout: Self.launchTimeout))
        return syncs
    }
}
