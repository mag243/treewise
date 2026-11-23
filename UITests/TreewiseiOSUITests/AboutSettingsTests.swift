import XCTest

/// Settings' About tab on the iPad (ADR 0143): the app's name and version, its links and
/// its licence, as the Mac's About panel shows them.
final class AboutSettingsTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testAboutShowsTheVersionTheLinksAndTheLicence() {
        let app = launch(state: UUID().uuidString)
        XCTAssertTrue(
            sidebar(of: app).staticTexts["Documents"].waitForExistence(timeout: Self.timeout))
        app.buttons["settings"].firstMatch.tap()
        let tab = app.buttons["About"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: Self.timeout), "Settings has an About tab")
        tab.tap()

        XCTAssertTrue(
            app.staticTexts["Treewise"].waitForExistence(timeout: Self.timeout), "its name")
        let version = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Version '")
        ).firstMatch
        XCTAssertTrue(version.exists, "its version")
        for link in ["Website", "GitHub", "Privacy"] {
            // A link on iOS 27, a button on iOS 18.
            XCTAssertTrue(
                app.links[link].exists || app.buttons[link].exists, "a link to the \(link) page")
        }
        let licence = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Mozilla'")
        ).firstMatch
        XCTAssertTrue(licence.exists, "its licence")
    }
}
