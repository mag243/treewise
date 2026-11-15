import XCTest

/// Settings' Templates tab deletes a template with −, which Undo brings back, and Export…
/// saves it where the user chooses (ADR 0091, ADR 0095).
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
    func testExportSavesTheTemplateWhereTheUserChooses() throws {
        try seedTwoTemplates()
        let root = try XCTUnwrap(self.root)
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
        XCTAssertEqual(
            panel.textFields.firstMatch.value as? String, "Client Folder Template.json",
            "it proposes a name that says what the file is, with its extension (ADR 0104)")
        // Go to the test's own folder, then save under the name proposed.
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(root.appendingPathComponent("Documents").path + "\r")
        // On a slow runner the panel may still be taking the path when typing returns,
        // and the Go to Folder field then lies over Save.
        let save = panel.buttons["Save"]
        XCTAssertTrue(app.eventually { save.isHittable }, "Go to Folder closes")
        save.click()
        XCTAssertTrue(panel.disappeared(timeout: Self.launchTimeout), "Save closes the panel")
        let saved = root.appendingPathComponent("Documents/Client Folder Template.json")
        let written = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: saved.path) },
            object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [written], timeout: Self.launchTimeout), .completed,
            "the template is in the file chosen")
    }

    @MainActor
    func templateName(_ name: String, in list: XCUIElement) -> XCUIElement {
        list.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch
    }

    /// Two invented templates where the app keeps a UI test's: beside its root.
    func seedTwoTemplates() throws {
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
