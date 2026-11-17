import XCTest

/// The iPhone's layout, modelled on Files (ADR 0132): the locations as a screen of their
/// own, a folder's enclosing folder to go up to, one menu, and while selecting a bar below.
/// Run on the pinned iPhone by `tools/build.sh iosuitest --iphone`; the iPads' runs skip it.
final class IPhoneTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    /// Starts in a state of its own, at the first location, Documents.
    @MainActor
    private func openDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testBackFromALocationShowsTheLocationsAndAnotherOneOpens() {
        let app = openDocuments()

        app.navigationBars["Documents"].buttons.firstMatch.tap()

        let work = sidebar(of: app).staticTexts["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: Self.timeout), "the locations' screen")
        work.tap()
        XCTAssertTrue(row("Report.txt", in: app).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testAFolderGoesUpToTheEnclosingFolderNamedOnItsButton() {
        let app = openDocuments()
        row("Projects", in: app).tap()
        let up = app.buttons["enclosingFolder"].firstMatch
        XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(up.label, "Documents")

        up.tap()

        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(app.buttons["enclosingFolder"].exists, "a location's top has none")
    }

    @MainActor
    func testTheMenuStartsSelectingAndTheBarBelowActsOnTheSelection() {
        let app = openDocuments()
        app.buttons["moreMenu"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()
        let copy = app.toolbars.buttons["Copy"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: Self.timeout), "the bar below")
        XCTAssertFalse(copy.isEnabled, "nothing selected yet")
        XCTAssertFalse(
            app.navigationBars.buttons["Treewise"].exists,
            "Select All takes the back button's place")

        row("Notes.md", in: app).tap()
        XCTAssertTrue(app.eventually { copy.isEnabled })
        copy.tap()
        app.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.eventually { !copy.exists }, "selecting ended")
        app.buttons["moreMenu"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Paste"].firstMatch.isEnabled, "the copy can be pasted")
    }
}
