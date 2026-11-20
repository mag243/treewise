import XCTest

/// A folder's Folder Structure ▸ on the iPad (ADR 0091, ADR 0142): its structure saved as a
/// template, and a template's folders made in it.
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
}
