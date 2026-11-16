import XCTest

/// Dragging items inside the iPad app (ADR 0047): a drop moves on the same volume, and a
/// drop the rules forbid changes nothing and says why as it lands (amended 2026-11-16).
final class DragTests: XCTestCase {
    static let timeout: TimeInterval = 10
    /// How long a press picks a row up before it moves.
    private static let pickUp: TimeInterval = 1

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    /// How long the finger rests on the target before it lifts, as a person's does.
    private static let rest: TimeInterval = 1

    /// Drags `item` onto `target` as a person does: picks it up, moves slowly and rests
    /// over the target, so iPadOS starts a drag rather than a context menu.
    @MainActor
    private func drag(_ item: XCUIElement, onto target: XCUIElement) {
        item.press(
            forDuration: Self.pickUp, thenDragTo: target, withVelocity: .slow,
            thenHoldForDuration: Self.rest)
    }

    /// Starts in Documents, with its files listed.
    @MainActor
    private func launchInDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testAFileDroppedOnALocationInTheSidebarMovesThere() {
        let app = launchInDocuments()
        let notes = row("Notes.md", in: app)
        drag(notes, onto: sidebar(of: app).staticTexts["Work"])
        XCTAssertTrue(notes.waitForNonExistence(timeout: Self.timeout), "it leaves Documents")
        sidebar(of: app).staticTexts["Work"].tap()
        XCTAssertTrue(
            row("Notes.md", in: app).waitForExistence(timeout: Self.timeout), "into Work")
    }

    @MainActor
    func testAFileDroppedOnTheLocationItIsInSaysItIsAlreadyThere() {
        let app = launchInDocuments()
        drag(row("Notes.md", in: app), onto: sidebar(of: app).staticTexts["Documents"])
        XCTAssertTrue(
            app.alerts["Already in ‘Documents’."].waitForExistence(timeout: Self.timeout),
            "the drop is refused with its reason")
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(row("Notes.md", in: app).exists, "and nothing moved")
    }
}
