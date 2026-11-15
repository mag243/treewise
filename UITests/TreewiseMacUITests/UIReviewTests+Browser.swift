import XCTest

/// The UI review's walk through the browser window (ADR 0103): `tools/build.sh uireview
/// browser`. The list, the details pane, the icon view and a second tab.
extension UIReviewTests {
    @MainActor
    func testBrowser() throws {
        try eachAppearance(browser)
    }

    @MainActor
    private func browser(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        let window = app.windows.firstMatch
        review(window, as: "browser-list", appearance: appearance)
        app.go(to: "Documents/Taxes", timeout: Self.timeout)
        let file = window.tables.staticTexts["Payment reminder.pdf"]
        XCTAssertTrue(file.waitForExistence(timeout: Self.timeout), "the folder's files show")
        file.click()
        app.typeKey("p", modifierFlags: [.command, .shift])
        settleScreen()
        review(window, as: "browser-details", appearance: appearance)
        app.typeKey("p", modifierFlags: [.command, .shift])
        app.typeKey("1", modifierFlags: .command)
        settleScreen()
        review(window, as: "browser-icons", appearance: appearance)
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("t", modifierFlags: .command)
        settleScreen()
        review(app.windows.firstMatch, as: "browser-tabs", appearance: appearance)
    }
}
