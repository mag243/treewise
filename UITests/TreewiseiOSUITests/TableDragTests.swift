import XCTest

/// Dropping on the rows of the iPad's table (ADR 0047, 0116).
final class TableDragTests: XCTestCase {
    static let timeout: TimeInterval = 10
    private static let pickUp: TimeInterval = 1
    private static let rest: TimeInterval = 1
    /// Longer than the progress bar's own delay of a second.
    private static let progressDelay: TimeInterval = 3

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func drag(_ item: XCUIElement, onto target: XCUIElement) {
        item.press(
            forDuration: Self.pickUp, thenDragTo: target, withVelocity: .slow,
            thenHoldForDuration: Self.rest)
    }

    @MainActor
    private func launchInDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testAFileDroppedOnAFolderInTheTableMovesIntoIt() {
        let app = launchInDocuments()
        let notes = row("Notes.md", in: app)
        drag(notes, onto: row("Projects", in: app))
        XCTAssertTrue(notes.waitForNonExistence(timeout: Self.timeout), "it leaves Documents")
        row("Projects", in: app).tap()
        XCTAssertTrue(
            row("Notes.md", in: app).waitForExistence(timeout: Self.timeout), "into Projects")
    }

    /// A drag from Treewise shows over a row whether it may drop there, as on the Mac
    /// (ADR 0116): one the rules forbid does not land, so nothing moves and nothing is said.
    @MainActor
    func testAFileOverItsOwnFolderInTheTableIsRefusedBeforeItLands() {
        let app = launchInDocuments()
        drag(row("Notes.md", in: app), onto: row("Budget.txt", in: app))
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "nothing to say")
        XCTAssertTrue(row("Notes.md", in: app).exists, "and nothing moved")
    }

    /// While the conflict sheet waits for an answer nothing is transferred, so the progress
    /// bar stays away instead of showing zero bytes behind the sheet.
    @MainActor
    func testTheProgressBarStaysAwayWhileTheConflictSheetAsks() {
        let app = launchInDocuments()
        drag(row("Budget.txt", in: app), onto: row("Projects", in: app))
        XCTAssertTrue(
            app.switches.firstMatch.waitForExistence(timeout: Self.timeout), "the conflict sheet")
        XCTAssertFalse(
            app.buttons["Pause"].waitForExistence(timeout: Self.progressDelay),
            "no progress behind it")
    }
}
