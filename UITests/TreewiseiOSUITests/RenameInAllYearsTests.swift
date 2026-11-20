import XCTest

/// Rename in All Years… on the iPad (ADR 0139): a folder inside a year's folder renamed in
/// every year beside it, and in the template the years were made from (ADR 0141).
final class RenameInAllYearsTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    /// Makes the fixture template's folders in Archive twice, for two years one after the
    /// other, as the sheet proposes the year after the last one there, and opens Archive.
    @MainActor
    private func openTwoYears() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Archive", in: app).waitForExistence(timeout: Self.timeout))
        for _ in 0...1 {
            row("Archive", in: app).press(forDuration: 1)
            app.buttons["Folder Structure"].firstMatch.tap()
            app.buttons["New Folders from Template"].firstMatch.tap()
            app.buttons["Household Year"].firstMatch.tap()
            let create = app.buttons["Create Folders"].firstMatch
            XCTAssertTrue(create.waitForExistence(timeout: Self.timeout))
            XCTAssertTrue(
                app.staticTexts["Makes 4 folders."].firstMatch.exists, "a year not made yet")
            create.tap()
            XCTAssertTrue(app.eventually { !create.exists }, "the folders are made")
        }
        row("Archive", in: app).tap()
        return app
    }

    @MainActor
    func testAFolderIsRenamedInEveryYearAndInItsTemplate() {
        let app = openTwoYears()
        let years = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]{4}$'"))
        XCTAssertTrue(app.eventually { years.count == 2 }, "two years' folders")
        let lastYear = years.element(boundBy: 1).label
        let yearBefore = years.element(boundBy: 0).label
        row(lastYear, in: app).tap()

        row("Tax", in: app).press(forDuration: 1)
        app.buttons["Rename in All Years…"].firstMatch.tap()
        let name = app.textFields["renameInAllYearsName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout), "the sheet opens")
        name.tap()
        name.typeText("es")
        XCTAssertTrue(
            app.switches["Household Year"].firstMatch.exists,
            "the template the years were made from is corrected along")
        let rename = app.buttons["renameInAllYearsRename"].firstMatch
        XCTAssertEqual(rename.label, "Rename 2 Folders")
        rename.tap()

        XCTAssertTrue(
            row("Taxes", in: app).waitForExistence(timeout: Self.timeout), "the last year")
        app.buttons["Back"].firstMatch.tap()
        row(yearBefore, in: app).tap()
        XCTAssertTrue(
            row("Taxes", in: app).waitForExistence(timeout: Self.timeout), "the year before")
    }
}
