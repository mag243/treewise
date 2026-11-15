import XCTest

/// The UI review's walk through alerts and sheets that ask something (ADR 0103):
/// `tools/build.sh uireview dialogs`. Each is cancelled, so nothing changes.
extension UIReviewTests {
    @MainActor
    func testDialogs() throws {
        try eachAppearance(dialogs)
    }

    @MainActor
    private func dialogs(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        XCTAssertTrue(settings.waitForExistence(timeout: Self.timeout), "Settings opens")
        open("Names", in: settings)
        press(settings.buttons["Clear Folder Settings…"])
        reviewAsked(
            on: settings, in: app, as: "dialogs-clear-folder-settings", appearance: appearance)
        open("Add-ons", in: settings)
        press(settings.buttons["Enter Licence Key…"])
        reviewAsked(on: settings, in: app, as: "dialogs-licence-key", appearance: appearance)
    }

    /// Reviews what `window` asks, as a sheet on it or as a dialog of its own, then cancels
    /// it with Escape.
    @MainActor
    private func reviewAsked(
        on window: XCUIElement, in app: XCUIApplication, as name: String, appearance: String?
    ) {
        let sheet = window.sheets.firstMatch
        let dialog = app.dialogs.firstMatch
        XCTAssertTrue(
            app.eventually { sheet.exists || dialog.exists }, "\(name) asks")
        let asked = sheet.exists ? sheet : dialog
        settleScreen()
        review(sheet.exists ? window : dialog, as: name, appearance: appearance)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(asked.waitForNonExistence(timeout: Self.timeout), "Escape cancels it")
    }
}
