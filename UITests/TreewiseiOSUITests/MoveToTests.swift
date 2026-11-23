import XCTest

/// Move to… and Copy to… on the iPad's wide table, from a row's context menu, with the
/// folders items were last moved or copied into at the top (ADR 0147).
final class MoveToTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testMoveToOffersTheFolderLastCopiedTo() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

        row("Budget.txt", in: app).press(forDuration: 1)
        app.buttons["Copy to…"].firstMatch.tap()
        let sheet = app.navigationBars["Copy to Folder"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout), "the sheet opens")
        app.buttons["Work"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Work"].waitForExistence(timeout: Self.timeout))
        app.buttons["moveToConfirm"].firstMatch.tap()

        row("Notes.md", in: app).press(forDuration: 1)
        app.buttons["Move to…"].firstMatch.tap()
        let recent = app.buttons["recent-Work"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: Self.timeout), "Work among Recent")
        recent.tap()
        XCTAssertTrue(app.navigationBars["Work"].waitForExistence(timeout: Self.timeout))
        app.buttons["moveToConfirm"].firstMatch.tap()

        let notes = row("Notes.md", in: app)
        XCTAssertTrue(app.eventually { !notes.exists }, "moved away")
    }
}
