import XCTest

/// The UI review's walk through the browser window (ADR 0103): `tools/build.sh uireview
/// browser`. The list, the command bar's menus, the context menus, the details pane, the
/// icon view, a split window, a second tab and About Treewise.
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
        reviewCommandBarMenus(in: window, app: app, appearance: appearance)
        reviewContextMenus(in: window, app: app, appearance: appearance)
        app.go(to: "Documents/Taxes", timeout: Self.timeout)
        let file = window.tables.staticTexts["Payment reminder.pdf"]
        XCTAssertTrue(file.waitForExistence(timeout: Self.timeout), "the folder's files show")
        press(file)
        app.typeKey("p", modifierFlags: [.command, .shift])
        settleScreen()
        review(window, as: "browser-details", appearance: appearance)
        app.typeKey("p", modifierFlags: [.command, .shift])
        app.typeKey("1", modifierFlags: .command)
        settleScreen()
        review(window, as: "browser-icons", appearance: appearance)
        app.typeKey("2", modifierFlags: .command)
        reviewSplitView(in: window, app: app, appearance: appearance)
        app.typeKey("t", modifierFlags: .command)
        settleScreen()
        review(app.windows.firstMatch, as: "browser-tabs", appearance: appearance)
        reviewAbout(in: app, appearance: appearance)
    }

    /// A split window (ADR 0154): the left half as a list, the right half, which has the
    /// focus, as icons; then the window alone again.
    @MainActor
    private func reviewSplitView(
        in window: XCUIElement, app: XCUIApplication, appearance: String?
    ) {
        app.typeKey("\\", modifierFlags: [.command, .control])
        XCTAssertTrue(app.eventually { window.tables.count + window.collectionViews.count == 2 })
        app.typeKey("1", modifierFlags: .command)
        settleScreen()
        review(
            window, as: "browser-split", appearance: appearance,
            also: statusBarsLevel(in: window))
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("\\", modifierFlags: [.command, .control])
    }

    /// What two frames' heights may differ by and still line up, as frames are rounded.
    private static let levelSlack: CGFloat = 1

    /// A finding when the halves' status bars do not line up: each half's view buttons
    /// sit at the same height, whatever the half shows.
    @MainActor
    private func statusBarsLevel(in window: XCUIElement) -> [UIReviewFinding] {
        let buttons = window.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "as List"))
            .allElementsBoundByIndex.map(\.frame)
        guard buttons.count == 2 else {
            return [
                UIReviewFinding(
                    check: "statusBarsLevel", element: "status bar",
                    detail: "found \(buttons.count) view buttons, not one in each half")
            ]
        }
        guard abs(buttons[0].minY - buttons[1].minY) > Self.levelSlack else { return [] }
        return [
            UIReviewFinding(
                check: "statusBarsLevel", element: "status bar",
                detail:
                    "the halves' view buttons sit at \(Int(buttons[0].minY)) and \(Int(buttons[1].minY))"
            )
        ]
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
