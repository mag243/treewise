import XCTest

/// Settings' General tab on the iPad (ADR 0143, ADR 0144): syncing through the cloud drives,
/// on unless turned off, and kept off.
final class GeneralSettingsTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testSyncingIsOnAndStaysOffOnceTurnedOff() {
        let state = UUID().uuidString
        let app = launch(state: state)
        XCTAssertTrue(
            sidebar(of: app).staticTexts["Documents"].waitForExistence(timeout: Self.timeout))
        app.buttons["settings"].firstMatch.tap()
        let syncs = app.switches["syncsSettings"].firstMatch
        XCTAssertTrue(syncs.waitForExistence(timeout: Self.timeout), "General opens first")
        XCTAssertEqual(syncs.value as? String, "1", "on by default")

        syncs.switches.firstMatch.tap()
        XCTAssertTrue(app.eventually { syncs.value as? String == "0" })
        app.terminate()

        let again = launch(state: state)
        again.buttons["settings"].firstMatch.tap()
        let kept = again.switches["syncsSettings"].firstMatch
        XCTAssertTrue(kept.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(kept.value as? String, "0", "kept off")
    }
}
