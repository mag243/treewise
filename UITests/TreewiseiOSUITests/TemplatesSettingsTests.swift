import XCTest

/// Settings' Templates tab on the iPad (ADR 0143): the fixture's template listed, its tree
/// opened, a folder renamed with Insert Field and one made inside from its menu.
final class TemplatesSettingsTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func openTemplate() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        XCTAssertTrue(
            sidebar(of: app).staticTexts["Documents"].waitForExistence(timeout: Self.timeout))
        app.buttons["settings"].firstMatch.tap()
        let tab = app.buttons["Templates"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: Self.timeout), "Settings has a Templates tab")
        tab.tap()
        let template = app.staticTexts["Household Year"].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: Self.timeout), "the template is listed")
        XCTAssertTrue(app.staticTexts["{year} · 3 folders"].exists, "with what it makes")
        template.tap()
        XCTAssertTrue(
            app.buttons["Receipts"].firstMatch.waitForExistence(timeout: Self.timeout),
            "its tree shows")
        return app
    }

    @MainActor
    func testAFolderOfATemplateIsRenamedWithAField() {
        let app = openTemplate()
        app.buttons["Receipts"].firstMatch.tap()
        let name = app.textFields["templateFolderName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout), "the folder's name opens")
        app.buttons["Insert Field"].firstMatch.tap()
        app.buttons["Each Quarter"].firstMatch.tap()
        XCTAssertEqual(name.value as? String, "Receipts Q{quarter}", "the field is added")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["Receipts Q{quarter}"].firstMatch.waitForExistence(timeout: Self.timeout),
            "the tree shows the new name")
    }

    @MainActor
    func testAFolderIsMadeInsideFromItsMenu() {
        let app = openTemplate()
        app.buttons["Tax"].firstMatch.press(forDuration: 1)
        app.buttons["New Folder Inside"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["untitled folder"].firstMatch.waitForExistence(timeout: Self.timeout),
            "a folder is made inside")
    }
}
