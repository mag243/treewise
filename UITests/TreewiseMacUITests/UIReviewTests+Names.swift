import XCTest

/// The UI review's walk through proposed names (ADR 0103): `tools/build.sh uireview
/// names`. The overview of a folder's names, with its add-ons header open.
extension UIReviewTests {
    @MainActor
    func testNames() throws {
        try eachAppearance(names)
    }

    @MainActor
    private func names(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        app.go(to: "Documents/Taxes", timeout: Self.timeout)
        XCTAssertTrue(
            app.tables.staticTexts["Payment reminder.pdf"].waitForExistence(timeout: Self.timeout))
        let file = app.menuBarItems["File"]
        file.click()
        file.menuItems["Suggest Names…"].click()
        let overview = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(overview.waitForExistence(timeout: Self.timeout), "the overview opens")
        settleScreen()
        review(overview, as: "names-overview", appearance: appearance)
        let header = overview.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add-ons:'"))
            .firstMatch
        if header.waitForExistence(timeout: Self.timeout) {
            header.click()
            settleScreen()
            review(overview, as: "names-add-ons", appearance: appearance)
        }
    }
}
