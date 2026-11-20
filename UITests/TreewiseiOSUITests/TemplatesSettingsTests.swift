import XCTest

/// Settings' Templates tab on the iPad (ADR 0143): the fixture's template listed, its tree
/// opened, a folder renamed with Insert Field and one made inside from its menu, that change
/// undone from the browser's toolbar, and Import… opening the picker.
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
        openTemplate(in: app)
        return app
    }

    @MainActor
    private func openTemplate(in app: XCUIApplication) {
        openTemplatesTab(in: app)
        let template = app.staticTexts["Household Year"].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: Self.timeout), "the template is listed")
        XCTAssertTrue(app.staticTexts["{year} · 3 folders"].exists, "with what it makes")
        template.tap()
        XCTAssertTrue(
            app.buttons["Receipts"].firstMatch.waitForExistence(timeout: Self.timeout),
            "its tree shows")
    }

    @MainActor
    private func openTemplatesTab(in app: XCUIApplication) {
        app.buttons["settings"].firstMatch.tap()
        let tab = app.buttons["Templates"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: Self.timeout), "Settings has a Templates tab")
        tab.tap()
    }

    @MainActor
    func testAFolderOfATemplateIsRenamedWithAField() {
        let app = openTemplate()
        app.buttons["Receipts"].firstMatch.tap()
        let name = app.textFields["templateFolderName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout), "the folder's name opens")
        app.buttons["Insert Field"].firstMatch.tap()
        let quarter = app.buttons["Each Quarter"].firstMatch
        XCTAssertTrue(quarter.waitForExistence(timeout: Self.timeout), "the fields are offered")
        quarter.tap()
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

    @MainActor
    func testAChangeToATemplateIsUndoneFromTheToolbar() {
        let app = openTemplate()
        app.buttons["Tax"].firstMatch.press(forDuration: 1)
        app.buttons["New Folder Inside"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["untitled folder"].firstMatch.waitForExistence(timeout: Self.timeout))
        app.navigationBars["Household Year"].buttons.firstMatch.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: Self.timeout), "back on the list")
        done.tap()

        let undo = app.buttons["undo"].firstMatch
        XCTAssertTrue(app.eventually { undo.isHittable && undo.isEnabled }, "Undo is offered")
        undo.tap()
        openTemplate(in: app)
        XCTAssertFalse(app.buttons["untitled folder"].firstMatch.exists, "the folder is undone")
    }

    @MainActor
    func testImportOpensThePicker() {
        let app = launch(state: UUID().uuidString)
        XCTAssertTrue(
            sidebar(of: app).staticTexts["Documents"].waitForExistence(timeout: Self.timeout))
        openTemplatesTab(in: app)
        app.buttons["templatesMore"].firstMatch.tap()
        let importItem = app.buttons["Import…"].firstMatch
        XCTAssertTrue(importItem.waitForExistence(timeout: Self.timeout))
        importItem.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: Self.timeout), "the picker opens")
        cancel.tap()
        XCTAssertTrue(
            app.staticTexts["Household Year"].firstMatch.waitForExistence(timeout: Self.timeout),
            "and closes on the list")
    }
}
