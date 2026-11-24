import XCTest

/// The details pane says which templates a folder was made from (ADR 0141), also for the
/// folder selected while a template fills it.
extension LaunchTests {
    private static let yearTemplate = "Plain Year"

    @MainActor
    func testTheDetailsPaneShowsMadeFromOnceATemplateFilledTheSelectedFolder() throws {
        try seedYearTemplate()
        try FileManager.default.createDirectory(
            at: try XCTUnwrap(root).appendingPathComponent("2028"),
            withIntermediateDirectories: true)
        let app = try launchApp()
        let window = app.windows.firstMatch
        let year = window.tables.staticTexts["2028"]
        XCTAssertTrue(year.appeared(timeout: Self.launchTimeout))
        window.checkBoxes["Details"].click()
        let details = window.groups["Details"]
        XCTAssertTrue(details.appeared(timeout: Self.launchTimeout), "the pane shows")

        year.rightClick()
        let menu = window.tables.menus.submenuItem(
            "New Folders from Template", in: "Folder Structure")
        XCTAssertTrue(menu.appeared(timeout: Self.launchTimeout), "the menu offers templates")
        menu.hover()
        menu.menuItems[Self.yearTemplate].click()
        let create = window.sheets.firstMatch.buttons["Create Folders"]
        XCTAssertTrue(create.appeared(timeout: Self.launchTimeout), "the sheet shows")
        create.click()
        XCTAssertTrue(
            window.staticTexts["Made 2 folders."].appeared(timeout: Self.launchTimeout),
            "the template filled the year")

        XCTAssertTrue(
            details.staticTexts["Made from"].appeared(timeout: Self.launchTimeout),
            "the pane says which template made the folder still selected")
    }

    /// Writes a year's template where the app keeps a UI test's templates: beside its root,
    /// in the folder named after it.
    private func seedYearTemplate() throws {
        let root = try XCTUnwrap(self.root)
        let settings = root.deletingLastPathComponent().appendingPathComponent(
            root.lastPathComponent + "-folder-settings", isDirectory: true)
        let folder = settings.appendingPathComponent("Templates", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: settings) }
        let template = """
            {"format": 1, "name": "\(Self.yearTemplate)", "root": {"name": "{year}", "folders": [
              {"name": "Receipts"}, {"name": "Tax"}]}}
            """
        try Data(template.utf8).write(to: folder.appendingPathComponent("year.json"))
    }
}
