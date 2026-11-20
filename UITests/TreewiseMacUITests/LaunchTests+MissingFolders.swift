import XCTest

/// The folders of the year before that a year's folder lacks (ADR 0102) are the paid add-on's:
/// without it, the bar, Add Missing Folders… and the checkbox in Settings do not show. With the
/// add-on they are left to `TemplateBarMissingTests`, as the open build carries none.
extension LaunchTests {
    @MainActor
    func testMissingFoldersAreNotOfferedWithoutTheAddOn() throws {
        let administration = try XCTUnwrap(root).appendingPathComponent("Administration")
        for path in ["2026/Tax", "2026/Receipts", "2027/Receipts"] {
            try FileManager.default.createDirectory(
                at: administration.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        let app = try launchApp()
        let window = app.windows.firstMatch
        let folder = window.tables.staticTexts["Administration"]
        XCTAssertTrue(folder.appeared(timeout: Self.launchTimeout))
        folder.doubleClick()
        let year = window.tables.staticTexts["2027"]
        XCTAssertTrue(year.appeared(timeout: Self.launchTimeout))
        year.rightClick()
        let menu = window.tables.menus.firstMatch
        XCTAssertTrue(
            menu.submenuItem("New Folders from Template", in: "Folder Structure").appeared(
                timeout: Self.launchTimeout),
            "the year's menu shows its template items")
        XCTAssertFalse(
            menu.submenuItem("Add Missing Folders from 2026…", in: "Folder Structure").exists,
            "without the add-on no missing folders are offered")
        app.typeKey(.escape, modifierFlags: [])
        year.doubleClick()
        XCTAssertTrue(window.tables.staticTexts["Receipts"].appeared(timeout: Self.launchTimeout))
        XCTAssertFalse(window.staticTexts["templateBarText"].exists, "nor a bar in 2027")
        let templates = openTemplatesTab(in: app)
        XCTAssertTrue(
            templates.tables["templatesList"].appeared(timeout: Self.launchTimeout))
        XCTAssertFalse(
            templates.checkBoxes["offersMissingFolders"].exists, "nor the checkbox in Settings")
    }
}
