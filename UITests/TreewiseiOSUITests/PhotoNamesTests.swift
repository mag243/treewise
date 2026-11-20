import XCTest

/// M6e's first acceptance criterion on the iPad: a folder of dated photos gets proposals from
/// the pattern recognized in its names and from a pattern typed, approved and undone (ADR 0129).
final class PhotoNamesTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testAPhotoIsNamedByItsDateFromTheRecognizedAndATypedPattern() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Work"].tap()
        let photos = row("Photos", in: app)
        XCTAssertTrue(photos.waitForExistence(timeout: Self.timeout))
        photos.tap()
        XCTAssertTrue(row("IMG_0042.jpg", in: app).waitForExistence(timeout: Self.timeout))

        app.buttons["viewMenu"].firstMatch.tap()
        app.buttons["Suggest Names for Whole Folder…"].firstMatch.tap()
        let proposal = app.textFields["proposal-IMG_0042.jpg"].firstMatch
        XCTAssertTrue(proposal.waitForExistence(timeout: Self.timeout), "the overview opens")
        XCTAssertTrue(
            app.eventually { (proposal.value as? String)?.hasPrefix("2025-03-16 ") == true },
            "the names' pattern is recognized and the photo's date proposed")

        let pattern = app.textFields["pattern"].firstMatch
        pattern.tap()
        // The field's clear button: a tap puts the caret where it lands, not at the end.
        pattern.buttons["Clear text"].tap()
        pattern.typeText("{date:yyyyMMdd} {text}")
        XCTAssertEqual(pattern.value as? String, "{date:yyyyMMdd} {text}", "the pattern typed")
        pattern.typeText("\n")
        XCTAssertTrue(
            app.eventually { (proposal.value as? String)?.hasPrefix("20250316 ") == true },
            "a typed pattern proposes from the same date")

        let named = (proposal.value as? String) ?? ""
        app.buttons["approve-IMG_0042.jpg"].firstMatch.tap()
        app.navigationBars.buttons["Rename"].tap()
        XCTAssertTrue(row(named, in: app).waitForExistence(timeout: Self.timeout), "renamed")
        app.buttons["undo"].firstMatch.tap()
        XCTAssertTrue(
            row("IMG_0042.jpg", in: app).waitForExistence(timeout: Self.timeout), "undone")
    }
}
