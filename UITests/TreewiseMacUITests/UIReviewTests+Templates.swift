import XCTest

/// The UI review's walk through folder templates (ADR 0103): `tools/build.sh uireview
/// templates`. The bar in an empty year and with missing folders, and the sheets that make
/// and save a structure, with the add-on in its trial.
extension UIReviewTests {
    @MainActor
    func testTemplates() throws {
        try eachAppearance(templates)
    }

    @MainActor
    private func templates(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        startTrials(in: app)
        let window = app.windows.firstMatch
        app.go(to: "Administration/2028", timeout: Self.timeout)
        let bar = window.buttons["templateBarCreate"]
        XCTAssertTrue(bar.waitForExistence(timeout: Self.timeout), "an empty year offers a bar")
        review(window, as: "templates-bar-empty", appearance: appearance)
        press(bar)
        reviewSheet(of: window, as: "templates-sheet-year", appearance: appearance)
        app.go(to: "../2027", timeout: Self.timeout)
        XCTAssertTrue(bar.waitForExistence(timeout: Self.timeout), "a year lacking folders too")
        review(window, as: "templates-bar-missing", appearance: appearance)
        press(bar)
        reviewSheet(of: window, as: "templates-sheet-missing", appearance: appearance)
        app.typeKey(.upArrow, modifierFlags: .command)
        XCTAssertTrue(
            app.windows(titled: "Administration").firstMatch.waitForExistence(
                timeout: Self.timeout), "the window shows Administration")
        let year = window.tables.staticTexts["2026"]
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout))
        press(year, in: window.scrollViews.firstMatch, .rightClick)
        press(window.tables.menus.menuItems["Save Folder Structure as Template…"])
        reviewSheet(of: window, as: "templates-sheet-save", appearance: appearance)
    }

    /// Reviews the sheet that opened on `window`, then cancels it.
    @MainActor
    private func reviewSheet(of window: XCUIElement, as name: String, appearance: String?) {
        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout), "the sheet opens")
        settleScreen()
        review(window, as: name, appearance: appearance)
        press(sheet.buttons["Cancel"])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: Self.timeout), "Cancel closes it")
    }
}
