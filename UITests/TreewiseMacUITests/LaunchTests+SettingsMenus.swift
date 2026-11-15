import XCTest

/// Settings' lists answer a right-click with what can be done to the row clicked, and
/// Duplicate puts a copy beside the original (ADR 0105).
extension LaunchTests {
    @MainActor
    func testATemplatesMenuDuplicatesItAndUndoTakesTheCopyBack() throws {
        try seedTwoTemplates()
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        let settings = openTemplatesTab(in: app)
        let list = settings.tables["templatesList"]
        let client = templateName("Client", in: list)
        XCTAssertTrue(client.appeared(timeout: Self.launchTimeout))
        client.rightClick()
        let menu = list.menus.firstMatch
        for item in ["Rename", "Duplicate", "Export…", "Delete Template"] {
            XCTAssertTrue(menu.menuItems[item].exists, "the menu offers \(item)")
        }
        menu.menuItems["Duplicate"].click()
        let copy = templateName("Client 2", in: list)
        XCTAssertTrue(copy.appeared(timeout: Self.launchTimeout), "Duplicate makes a copy")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(copy.disappeared(timeout: Self.launchTimeout), "Undo takes it back")
    }

    @MainActor
    func testAFoldersMenuInATemplateOffersItsFields() throws {
        try seedTwoTemplates()
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        let settings = openTemplatesTab(in: app)
        let tree = settings.outlines["templateTreeEditor"]
        let tax = templateName("Tax", in: tree)
        XCTAssertTrue(tax.appeared(timeout: Self.launchTimeout))
        tax.rightClick()
        let menu = tree.menus.firstMatch
        for item in ["New Folder", "Rename", "Insert Field", "Delete"] {
            XCTAssertTrue(menu.menuItems[item].exists, "the menu offers \(item)")
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testAPatternsMenuDuplicatesIt() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        settings.toolbars.buttons["Names"].click()
        let list = settings.tables.firstMatch
        let pattern = list.staticTexts["Folder and Number"]
        XCTAssertTrue(pattern.appeared(timeout: Self.launchTimeout))
        pattern.rightClick()
        let menu = list.menus.firstMatch
        for item in ["Make Default", "Duplicate", "Delete"] {
            XCTAssertTrue(menu.menuItems[item].exists, "the menu offers \(item)")
        }
        menu.menuItems["Duplicate"].click()
        XCTAssertTrue(
            list.staticTexts["Folder and Number 2"].appeared(timeout: Self.launchTimeout),
            "Duplicate puts a copy beside it")
    }
}
