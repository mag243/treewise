import XCTest

/// Settings from the sidebar's gear (ADR 0130) and the sidebar's Favorites (ADR 0131).
final class SettingsAndFavoritesTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func openDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testTheGearOpensSettingsWhereAPatternIsAdded() {
        let app = openDocuments()
        app.buttons["settings"].firstMatch.tap()
        app.buttons["Names"].firstMatch.tap()
        let saved = app.buttons["savedPatterns"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: Self.timeout))

        saved.tap()
        XCTAssertFalse(app.staticTexts["New Pattern"].exists)
        app.buttons["Add Pattern"].firstMatch.tap()

        let editor = app.navigationBars["New Pattern"]
        XCTAssertTrue(editor.waitForExistence(timeout: Self.timeout), "the new one opens")
        XCTAssertTrue(app.textFields["pattern"].exists)
        editor.buttons["Saved Patterns"].tap()
        XCTAssertTrue(
            app.staticTexts["New Pattern"].waitForExistence(timeout: Self.timeout),
            "it is in the list")
    }

    @MainActor
    func testAFavoriteSwipedAwayIsRemoved() {
        let app = openDocuments()
        row("Projects", in: app).press(forDuration: 1)
        app.buttons["Add to Favorites"].firstMatch.tap()
        let favorite = sidebar(of: app).staticTexts["Projects"]
        XCTAssertTrue(favorite.waitForExistence(timeout: Self.timeout), "in Favorites")

        swipeLeft(favorite)
        let remove = app.buttons["Remove from Favorites"].firstMatch
        if remove.waitForExistence(timeout: 2) { remove.tap() }

        XCTAssertTrue(app.eventually { !favorite.exists }, "removed")
        XCTAssertEqual(app.state, .runningForeground, "still running")
    }

    @MainActor
    func testAFolderAddedToFavoritesOpensFromTheSidebarAndIsRemoved() {
        let app = openDocuments()
        row("Projects", in: app).press(forDuration: 1)
        app.buttons["Add to Favorites"].firstMatch.tap()

        let favorite = sidebar(of: app).staticTexts["Projects"]
        XCTAssertTrue(favorite.waitForExistence(timeout: Self.timeout), "in Favorites")
        favorite.tap()
        XCTAssertTrue(row("Budget.txt", in: app).waitForExistence(timeout: Self.timeout), "opened")

        favorite.press(forDuration: 1)
        app.buttons["Remove from Favorites"].firstMatch.tap()
        XCTAssertTrue(app.eventually { !favorite.exists }, "removed")
    }
}
