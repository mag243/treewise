import XCTest

/// The iPhone's UI review (ADR 0115, 0132): its screens walked as the iPad's are, on the
/// pinned iPhone. Run by `tools/build.sh iosreview`, which makes one report with the iPads';
/// `iosuitest` skips this class. A finding does not fail the walk.
final class IPhoneReviewTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Screens

    @MainActor
    func testStart() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString, fixture: false)
            XCTAssertTrue(
                app.buttons["Add Location"].firstMatch.waitForExistence(timeout: Self.timeout))
            review(app, as: "start", variant: variant)
            app.terminate()
        }
    }

    /// A folder, its menu, selecting, a folder below a location's top and the locations.
    @MainActor
    func testBrowser() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            review(app, as: "folder", variant: variant)

            app.buttons["moreMenu"].firstMatch.tap()
            let select = app.buttons["Select"].firstMatch
            XCTAssertTrue(select.waitForExistence(timeout: Self.timeout), "the menu")
            review(app, as: "more-menu", variant: variant)
            select.tap()
            row("Notes.md", in: app).tap()
            review(app, as: "selecting", variant: variant)
            app.buttons["Done"].firstMatch.tap()

            row("Projects", in: app).tap()
            let up = app.buttons["enclosingFolder"].firstMatch
            XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
            review(app, as: "subfolder", variant: variant)
            up.tap()

            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            app.navigationBars["Documents"].buttons.firstMatch.tap()
            XCTAssertTrue(
                sidebar(of: app).staticTexts["Work"].waitForExistence(timeout: Self.timeout))
            review(app, as: "locations", variant: variant)
            app.terminate()
        }
    }

    /// The rename sheet with its proposals and the name overview (ADR 0129, 0130).
    @MainActor
    func testNames() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

            perform("Rename with Suggestions…", on: "Notes.md", in: app)
            XCTAssertTrue(app.buttons["suggestion-0"].waitForExistence(timeout: Self.timeout))
            review(app, as: "rename-suggestions", variant: variant)
            app.navigationBars["Rename"].buttons["Cancel"].tap()
            app.buttons["Done"].firstMatch.tap()

            perform("Suggest Names…", on: "Notes.md", in: app)
            let proposal = app.textFields["proposal-Notes.md"].firstMatch
            XCTAssertTrue(proposal.waitForExistence(timeout: Self.timeout))
            review(app, as: "name-overview", variant: variant)
            app.terminate()
        }
    }

    /// Settings and its saved patterns, from the locations' screen (ADR 0130).
    @MainActor
    func testSettings() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            app.navigationBars["Documents"].buttons.firstMatch.tap()
            app.buttons["settings"].firstMatch.tap()
            let saved = app.buttons["savedPatterns"].firstMatch
            XCTAssertTrue(saved.waitForExistence(timeout: Self.timeout))
            review(app, as: "settings", variant: variant)
            saved.tap()
            review(app, as: "saved-patterns", variant: variant)
            app.terminate()
        }
    }

    // MARK: - Doing

    /// Performs a row's command through the folder's menu, Select and the Actions menu
    /// below; selecting goes on until the caller ends it.
    @MainActor
    private func perform(_ command: String, on name: String, in app: XCUIApplication) {
        app.buttons["moreMenu"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()
        row(name, in: app).tap()
        app.toolbars.buttons["Actions"].firstMatch.tap()
        let item = app.buttons[command].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.timeout), "\(command) in Actions")
        item.tap()
    }
}
