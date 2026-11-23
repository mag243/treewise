import XCTest

/// Settings' Templates tab on the iPad (ADR 0143): the fixture's template listed, its tree
/// opened, a folder renamed with Insert Field and one made inside from its menu, that change
/// undone from the browser's toolbar, and a template exported and imported again, which
/// asks to replace it or keep both.
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

    /// Exports the fixture's template to On My iPad and imports that file again: the template
    /// is here already, so Treewise asks to replace it or keep both (ADR 0141).
    @MainActor
    func testImportingATemplateThatIsHereAsksReplaceOrKeepBoth() {
        let app = openTemplate()
        app.buttons["More"].firstMatch.tap()
        app.buttons["Export…"].firstMatch.tap()
        // The exporter opens in On My iPad; a run before may have left the file there. On
        // iOS 27 it asks for a name and shows its Save only once the name field is touched;
        // on iOS 18 it has no name field and its button is Move.
        let nameField = app.textFields["DOCPicker.filenameTextField"]
        if nameField.waitForExistence(timeout: Self.timeout / 2) { nameField.tap() }
        var move = app.buttons["DOCPicker.actionButton"].firstMatch
        if !move.waitForExistence(timeout: Self.timeout / 2) {
            move = app.buttons["Move"].firstMatch
        }
        XCTAssertTrue(move.waitForExistence(timeout: Self.timeout), "the exporter opens")
        move.tap()
        let replace = app.buttons["Replace"].firstMatch
        if replace.waitForExistence(timeout: 2) { replace.tap() }
        XCTAssertTrue(app.eventually { !move.exists }, "the exporter closes")
        app.navigationBars["Household Year"].buttons["Templates"].tap()
        let more = app.buttons["templatesMore"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: Self.timeout), "back on the list")
        more.tap()
        app.buttons["Import…"].firstMatch.tap()
        let file = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Household Year Folder Template'")
        ).firstMatch
        if !file.waitForExistence(timeout: Self.timeout) {
            app.staticTexts["On My iPad"].firstMatch.tap()
        }
        XCTAssertTrue(file.waitForExistence(timeout: Self.timeout), "the file exported")
        // The picker's file is a cell holding its icon and name; a tap on its name may land
        // beside the cell, so the cell itself is tapped.
        let cell = app.cells.containing(.staticText, identifier: file.label).firstMatch
        (cell.exists ? cell : file).tap()

        let keepBoth = app.buttons["Keep Both"].firstMatch
        XCTAssertTrue(
            keepBoth.waitForExistence(timeout: Self.timeout), "it asks, as the template is here")
        XCTAssertTrue(app.buttons["Replace"].firstMatch.exists)
        keepBoth.tap()
        // The copy takes a name of its own; both make the same folders.
        let listed = app.staticTexts.matching(NSPredicate(format: "label == '{year} · 3 folders'"))
        XCTAssertTrue(app.eventually { listed.count == 2 }, "both are kept")
    }
}
