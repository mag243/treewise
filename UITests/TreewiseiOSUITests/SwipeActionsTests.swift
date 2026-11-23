import XCTest

/// A folder's rows take a swipe (ADR 0146): to the left Move to Trash and More…, to the
/// right Cut and Copy; none while selecting.
final class SwipeActionsTests: XCTestCase {
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

    /// Drags a finger part of the way across a row, which shows its swipe actions without
    /// performing the first.
    @MainActor
    private func reveal(_ element: XCUIElement, fromTheRight: Bool) {
        let (from, to): (CGFloat, CGFloat) = fromTheRight ? (0.8, 0.45) : (0.05, 0.4)
        element.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: element.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.5)))
    }

    @MainActor
    private func tableRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.collectionViews["folderTable"].cells.containing(.staticText, identifier: name)
            .firstMatch
    }

    @MainActor
    func testASwipeToTheLeftOffersMoveToTrash() {
        let app = openDocuments()
        reveal(tableRow("Notes.md", in: app), fromTheRight: true)

        let trash = app.buttons["Move to Trash"].firstMatch
        XCTAssertTrue(trash.waitForExistence(timeout: Self.timeout), "the swipe shows it")
        trash.tap()

        // The simulator's folders have no Trash, so it asks first (ADR 0128).
        let offer = app.alerts.buttons["Delete Permanently…"]
        XCTAssertTrue(offer.waitForExistence(timeout: Self.timeout), "it went to Move to Trash")
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(row("Notes.md", in: app).exists, "nothing is deleted unasked")
    }

    @MainActor
    func testMoreShowsTheRowsOtherCommands() {
        let app = openDocuments()
        reveal(tableRow("Notes.md", in: app), fromTheRight: true)

        let more = app.buttons["More…"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: Self.timeout), "the swipe shows More…")
        more.tap()
        let rename = app.buttons["Rename"].firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: Self.timeout), "More… lists Rename")
        rename.tap()

        XCTAssertTrue(
            app.navigationBars["Rename"].waitForExistence(timeout: Self.timeout),
            "Rename asks for the name")
    }

    @MainActor
    func testASwipeToTheRightCutsTheRowForPasteElsewhere() {
        let app = openDocuments()
        reveal(tableRow("Notes.md", in: app), fromTheRight: false)

        let cut = app.buttons["Cut"].firstMatch
        XCTAssertTrue(cut.waitForExistence(timeout: Self.timeout), "the swipe shows Cut")
        XCTAssertTrue(app.buttons["Copy"].firstMatch.exists, "and Copy")
        cut.tap()
        row("Projects", in: app).tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: Self.timeout))
        app.buttons["Paste"].firstMatch.tap()

        XCTAssertTrue(
            row("Notes.md", in: app).waitForExistence(timeout: Self.timeout), "moved here")
    }

    @MainActor
    func testRowsTakeNoSwipeWhileSelecting() {
        let app = openDocuments()
        app.buttons["Select"].firstMatch.tap()

        reveal(tableRow("Notes.md", in: app), fromTheRight: true)

        XCTAssertFalse(
            app.buttons["Move to Trash"].firstMatch.waitForExistence(timeout: 2),
            "a swipe while selecting shows no actions")
    }
}
