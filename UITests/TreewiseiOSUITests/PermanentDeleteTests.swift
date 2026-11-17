import XCTest

/// Where a location has no Trash, as in the simulator, Move to Trash's alert offers
/// Delete Permanently…, which asks once more (ADR 0128).
final class PermanentDeleteTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testMoveToTrashWithoutATrashOffersToDeletePermanentlyAfterAsking() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        let notes = row("Notes.md", in: app)
        XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))

        notes.press(forDuration: 1)
        app.buttons["Move to Trash"].firstMatch.tap()
        let offer = app.alerts.buttons["Delete Permanently…"]
        XCTAssertTrue(
            offer.waitForExistence(timeout: Self.timeout),
            "the alert offers it; alerts: \(app.alerts.count) "
                + "\(app.alerts.firstMatch.label), Notes.md there: \(notes.exists)")
        offer.tap()
        let confirmation = app.alerts["Delete “Notes.md” permanently?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: Self.timeout), "it asks once more")
        confirmation.buttons["Delete"].tap()

        XCTAssertTrue(app.eventually { !notes.exists }, "deleted")
        XCTAssertTrue(row("Budget.txt", in: app).exists, "the rest stays")
    }
}
