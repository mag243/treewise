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
        review(
            window, as: "browser-list", appearance: appearance,
            also: sidebarWidth(in: window))
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

    /// The width a new window's sidebar starts at, `SidebarWidth.ideal` (ADR 0093), which the
    /// app's settings, fresh in a review, have not changed.
    private static let sidebarStart: CGFloat = 260

    /// A finding when a new window's sidebar starts narrower than it should.
    @MainActor
    private func sidebarWidth(in window: XCUIElement) -> [UIReviewFinding] {
        let sidebar = window.outlines.firstMatch.frame
        // The sidebar's list sits inside it with a little room on either side.
        guard sidebar.width < Self.sidebarStart - 2 * UIReviewChecks.listMargin * 4 else {
            return []
        }
        return [
            UIReviewFinding(
                check: "sidebarStart", element: "sidebar",
                detail:
                    "a new window's sidebar is \(Int(sidebar.width)) wide, not \(Int(Self.sidebarStart))"
            )
        ]
    }
}
