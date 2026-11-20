import XCTest

/// A folder's Folder Structure ▸ on the iPad (ADR 0091, ADR 0099, ADR 0142): its structure
/// saved as a template, a template's folders made in it, its structure copied and pasted
/// into another folder, and the template a folder was made from forgotten with Undo.
final class FolderStructureTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func openDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Archive", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    /// Opens Folder Structure ▸ in the menu of the folder `name`.
    @MainActor
    private func openFolderStructure(of name: String, in app: XCUIApplication) {
        row(name, in: app).press(forDuration: 1)
        let structure = app.buttons["Folder Structure"].firstMatch
        XCTAssertTrue(structure.waitForExistence(timeout: Self.timeout), "the folder's menu")
        structure.tap()
    }

    @MainActor
    func testAFoldersStructureIsSavedAsATemplate() {
        let app = openDocuments()
        openFolderStructure(of: "Projects", in: app)
        app.buttons["Save as Template…"].firstMatch.tap()
        let name = app.textFields["templateName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout), "the sheet asks a name")
        XCTAssertEqual(name.value as? String, "Projects", "named after the folder")
        app.buttons["Save"].firstMatch.tap()

        app.buttons["settings"].firstMatch.tap()
        app.buttons["Templates"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Projects · 0 folders"].firstMatch.waitForExistence(
                timeout: Self.timeout), "the template is listed, with what it makes")
    }

    @MainActor
    func testATemplatesFoldersAreMadeInAFolder() {
        let app = openDocuments()
        openFolderStructure(of: "Archive", in: app)
        app.buttons["New Folders from Template"].firstMatch.tap()
        app.buttons["Household Year"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Makes 4 folders."].firstMatch.waitForExistence(
                timeout: Self.timeout), "the sheet shows what it makes")
        app.buttons["Create Folders"].firstMatch.tap()

        row("Archive", in: app).tap()
        let year = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]{4}$'"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout), "the year's folder is made")
        year.tap()
        XCTAssertTrue(
            row("Tax", in: app).waitForExistence(timeout: Self.timeout), "with its folders")
    }

    @MainActor
    func testAFoldersStructureIsCopiedAndPastedIntoAnother() {
        let app = openDocuments()
        openFolderStructure(of: "Archive", in: app)
        XCTAssertFalse(
            app.buttons["Paste Structure…"].firstMatch.exists, "nothing is copied yet")
        app.buttons["Copy Structure"].firstMatch.tap()

        openFolderStructure(of: "Projects", in: app)
        let paste = app.buttons["Paste Structure…"].firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: Self.timeout), "once one is copied")
        paste.tap()
        let create = app.buttons["Create Folders"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: Self.timeout), "the sheet opens")
        XCTAssertTrue(app.staticTexts["Makes 1 folder."].firstMatch.exists, "what it makes")
        create.tap()

        row("Projects", in: app).tap()
        XCTAssertTrue(
            row("Archive", in: app).waitForExistence(timeout: Self.timeout),
            "the structure is made inside")
    }

    @MainActor
    func testTheTemplateAFolderWasMadeFromIsForgottenAndUndone() {
        let app = openDocuments()
        openFolderStructure(of: "Archive", in: app)
        app.buttons["New Folders from Template"].firstMatch.tap()
        app.buttons["Household Year"].firstMatch.tap()
        let create = app.buttons["Create Folders"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: Self.timeout))
        create.tap()
        row("Archive", in: app).tap()
        let year = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]{4}$'"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout))
        let name = year.label

        openFolderStructure(of: name, in: app)
        app.buttons["Made from"].firstMatch.tap()
        let forget = app.buttons["Forget “Household Year”"].firstMatch
        XCTAssertTrue(forget.waitForExistence(timeout: Self.timeout), "it was made from it")
        forget.tap()

        openFolderStructure(of: name, in: app)
        XCTAssertTrue(
            app.buttons["Save as Template…"].firstMatch.waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(app.buttons["Made from"].firstMatch.exists, "forgotten")
        app.buttons["Save as Template…"].firstMatch.tap()
        app.buttons["Cancel"].firstMatch.tap()

        let undo = app.buttons["undo"].firstMatch
        XCTAssertTrue(app.eventually { undo.isEnabled })
        undo.tap()
        openFolderStructure(of: name, in: app)
        XCTAssertTrue(
            app.buttons["Made from"].firstMatch.waitForExistence(timeout: Self.timeout),
            "remembered again")
    }

    /// M6e's acceptance criterion: a template saved from one folder makes the same folders in
    /// another, with a field filled in. The iPad saves names as written, so the year's folder
    /// gets its field in Settings' Templates tab first.
    @MainActor
    func testATemplateSavedFromAFolderMakesItsFoldersElsewhereWithAField() {
        let app = openDocuments()
        openFolderStructure(of: "Archive", in: app)
        app.buttons["New Folders from Template"].firstMatch.tap()
        app.buttons["Household Year"].firstMatch.tap()
        let create = app.buttons["Create Folders"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: Self.timeout))
        create.tap()
        row("Archive", in: app).tap()
        let year = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]{4}$'"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout))
        let yearName = year.label

        openFolderStructure(of: yearName, in: app)
        app.buttons["Save as Template…"].firstMatch.tap()
        let name = app.textFields["templateName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(name.value as? String, "Archive Year", "named after the folder above")
        app.buttons["Save"].firstMatch.tap()

        giveTheRootTheYearField(of: "Archive Year", named: yearName, in: app)

        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Projects", in: app).waitForExistence(timeout: Self.timeout))
        openFolderStructure(of: "Projects", in: app)
        app.buttons["New Folders from Template"].firstMatch.tap()
        app.buttons["Archive Year"].firstMatch.tap()
        XCTAssertTrue(create.waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(app.steppers.firstMatch.exists, "the year is asked")
        create.tap()
        row("Projects", in: app).tap()
        let made = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]{4}$'"))
            .firstMatch
        XCTAssertTrue(made.waitForExistence(timeout: Self.timeout), "the year's folder is made")
        made.tap()
        XCTAssertTrue(row("Tax", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(row("Receipts", in: app).exists, "with the same folders")
    }

    /// In Settings' Templates tab, renames the root `root` of the template `template` to the
    /// year's field, and closes Settings.
    @MainActor
    private func giveTheRootTheYearField(
        of template: String, named root: String, in app: XCUIApplication
    ) {
        app.buttons["settings"].firstMatch.tap()
        app.buttons["Templates"].firstMatch.tap()
        app.staticTexts[template].firstMatch.tap()
        let rootRow = app.buttons[root].firstMatch
        XCTAssertTrue(rootRow.waitForExistence(timeout: Self.timeout))
        rootRow.tap()
        let field = app.textFields["templateFolderName"]
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        // A tap at the field's end puts the caret after the name, which the deletes take.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: root.count))
        app.buttons["Insert Field"].firstMatch.tap()
        app.buttons["Year"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "{year}")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["{year}"].firstMatch.waitForExistence(timeout: Self.timeout))
        app.navigationBars[template].buttons.firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()
    }
}
