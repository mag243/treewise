import XCTest

/// Settings' Templates tab deletes a template with −, which Undo brings back, and Export…
/// asks where to save it (ADR 0091, ADR 0095).
extension LaunchTests {
    @MainActor
    func testDeletingATemplateRemovesItAndUndoBringsItBack() throws {
        try seedTwoTemplates()
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        let settings = openTemplatesTab(in: app)
        let list = settings.tables["templatesList"]
        let client = templateName("Client", in: list)
        XCTAssertTrue(client.appeared(timeout: Self.launchTimeout), "the templates are listed")
        client.click()
        let delete = settings.buttons["Delete Template"]
        XCTAssertTrue(delete.isEnabled, "a template is selected")
        delete.click()
        XCTAssertTrue(
            client.disappeared(timeout: Self.launchTimeout), "Delete Template removes it")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(client.appeared(timeout: Self.launchTimeout), "Undo brings it back")
    }

    @MainActor
    func testExportAsksWhereToSaveTheTemplate() throws {
        try seedTwoTemplates()
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        let settings = openTemplatesTab(in: app)
        let client = templateName("Client", in: settings.tables["templatesList"])
        XCTAssertTrue(client.appeared(timeout: Self.launchTimeout))
        client.click()
        settings.buttons["Export…"].click()
        let panel = settings.sheets.firstMatch
        XCTAssertTrue(panel.appeared(timeout: Self.launchTimeout), "Export… asks where to save")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(panel.disappeared(timeout: Self.launchTimeout))
    }

    @MainActor
    private func templateName(_ name: String, in list: XCUIElement) -> XCUIElement {
        list.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch
    }

    /// Two invented templates where the app keeps a UI test's: beside its root.
    private func seedTwoTemplates() throws {
        let root = try XCTUnwrap(self.root)
        let settings = root.deletingLastPathComponent().appendingPathComponent(
            root.lastPathComponent + "-folder-settings", isDirectory: true)
        let folder = settings.appendingPathComponent("Templates", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: settings) }
        for (file, name) in [("client", "Client"), ("year", "Household Year")] {
            let template = """
                {"format": 1, "name": "\(name)", "root": {"name": "{year}", "folders": [
                  {"name": "Tax"}]}}
                """
            try Data(template.utf8).write(to: folder.appendingPathComponent("\(file).json"))
        }
    }
}
