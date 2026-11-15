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
        review(
            overview, as: "names-overview", appearance: appearance,
            also: headingsWithoutContent(["In This Folder"], in: overview))
        let header = overview.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add-ons:'"))
            .firstMatch
        if header.waitForExistence(timeout: Self.timeout) {
            header.click()
            settleScreen()
            review(overview, as: "names-add-ons", appearance: appearance)
        }
    }

    /// How far below a heading the first of what it heads may start.
    private static let underHeading: CGFloat = 30

    /// A finding for each of `headings` that shows with nothing under it: a heading over an
    /// empty section.
    @MainActor
    func headingsWithoutContent(_ headings: [String], in window: XCUIElement)
        -> [UIReviewFinding]
    {
        let texts = window.staticTexts.allElementsBoundByIndex
        return headings.compactMap { heading in
            guard let title = texts.first(where: { ($0.value as? String) == heading }) else {
                return nil
            }
            let below = texts.contains { text in
                text.frame.minY >= title.frame.maxY
                    && text.frame.minY - title.frame.maxY < Self.underHeading
                    && text.frame.minX < title.frame.maxX && text.frame.maxX > title.frame.minX
            }
            return below
                ? nil
                : UIReviewFinding(
                    check: "emptySection", element: "text \"\(heading)\"",
                    detail: "a heading with nothing under it")
        }
    }
}
