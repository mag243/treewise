import XCTest

/// Folder structure templates, which are Treewise's own and work without the add-on (ADR 0091,
/// ADR 0095, ADR 0099): saving a folder's structure, making it in another folder, and editing
/// a template's tree in Settings. The app keeps a UI test's templates apart from the user's.
/// Undoing the folders made is left to `BrowserStateFolderTemplateTests`, as it moves them to
/// the Trash.
extension LaunchTests {
    private static let client = "Client A"

    @MainActor
    func testSavingAFoldersStructureListsItInSettings() throws {
        try makeClientFolder()
        let app = try launchApp()
        try saveClientTemplate(in: app)
        let templates = openTemplatesTab(in: app)
        XCTAssertTrue(
            field(Self.client, in: templates.tables["templatesList"]).appeared(
                timeout: Self.launchTimeout), "the template is listed under the folder's name")
        let tree = templates.outlines["templateTreeEditor"]
        XCTAssertTrue(field("Contract", in: tree).exists, "its folders show below it")
        XCTAssertTrue(field("Invoices", in: tree).exists)
        XCTAssertGreaterThan(
            tree.frame.width, templates.frame.width * 0.8, "the tree takes the tab's width")
    }

    @MainActor
    func testNewFoldersFromTemplateMakesTheTemplatesFolders() throws {
        try makeClientFolder()
        let app = try launchApp()
        try saveClientTemplate(in: app)
        let window = app.windows.firstMatch
        window.tables.staticTexts["Documents"].rightClick()
        let menu = window.tables.menus.menuItems["New Folders from Template"]
        XCTAssertTrue(menu.appeared(timeout: Self.launchTimeout), "the menu offers templates")
        menu.hover()
        menu.menuItems[Self.client].click()
        let sheet = window.sheets.firstMatch
        let create = sheet.buttons["Create Folders"]
        XCTAssertTrue(create.appeared(timeout: Self.launchTimeout), "the sheet shows")
        XCTAssertTrue(sheet.staticTexts["Makes 3 folders."].exists, "it says what it makes")
        create.click()
        XCTAssertTrue(
            window.staticTexts["Made 3 folders."].appeared(timeout: Self.launchTimeout),
            "the status bar says what was made")
        let root = try XCTUnwrap(root)
        for path in ["Client A", "Client A/Contract", "Client A/Invoices"] {
            var isFolder: ObjCBool = false
            let url = root.appendingPathComponent("Documents/" + path)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder)
                    && isFolder.boolValue, "\(path) is made")
        }
    }

    @MainActor
    func testAFolderAddedToATemplateInSettingsIsUndone() throws {
        try makeClientFolder()
        let app = try launchApp()
        try saveClientTemplate(in: app)
        let templates = openTemplatesTab(in: app)
        let tree = templates.outlines["templateTreeEditor"]
        let root = tree.outlineRows.containing(
            NSPredicate(format: "value == %@", Self.client)
        ).firstMatch
        XCTAssertTrue(root.appeared(timeout: Self.launchTimeout))
        root.click()
        templates.buttons["Add Folder"].click()
        let added = field("untitled folder", in: tree)
        XCTAssertTrue(added.appeared(timeout: Self.launchTimeout), "the folder is added")
        XCTAssertTrue(
            app.eventually { (added.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "and its name is being edited")
        app.typeKey("a", modifierFlags: .command)
        for key in "Receipts" { app.typeKey(String(key), modifierFlags: []) }
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            field("Receipts", in: tree).appeared(timeout: Self.launchTimeout),
            "the folder is added and named")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(
            field("Receipts", in: tree).disappeared(timeout: Self.launchTimeout),
            "Undo takes the rename back")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(
            field("untitled folder", in: tree).disappeared(timeout: Self.launchTimeout),
            "and then the folder added")
        XCTAssertTrue(field("Contract", in: tree).exists, "the template's own folders stay")
    }

    /// The editable name `name` in a list or tree of Settings, matched by its value.
    @MainActor
    private func field(_ name: String, in list: XCUIElement) -> XCUIElement {
        list.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch
    }

    /// `Projects/Client A` with the folders Contract and Invoices.
    private func makeClientFolder() throws {
        let client = try XCTUnwrap(root).appendingPathComponent("Projects/" + Self.client)
        for folder in ["Contract", "Invoices"] {
            try FileManager.default.createDirectory(
                at: client.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
    }

    /// Opens Projects and saves Client A's structure under the name proposed, its own.
    @MainActor
    private func saveClientTemplate(in app: XCUIApplication) throws {
        let window = app.windows.firstMatch
        let projects = window.tables.staticTexts["Projects"]
        XCTAssertTrue(projects.appeared(timeout: Self.launchTimeout))
        projects.doubleClick()
        let client = window.tables.staticTexts[Self.client]
        XCTAssertTrue(client.appeared(timeout: Self.launchTimeout))
        client.rightClick()
        window.tables.menus.menuItems["Save Folder Structure as Template…"].click()
        let sheet = window.sheets.firstMatch
        let name = sheet.textFields["templateName"]
        XCTAssertTrue(name.appeared(timeout: Self.launchTimeout), "the sheet asks for a name")
        XCTAssertEqual(name.value as? String, Self.client, "it proposes the folder's name")
        sheet.buttons["Save"].click()
        XCTAssertTrue(sheet.disappeared(timeout: Self.launchTimeout), "Save closes the sheet")
        app.typeKey(.upArrow, modifierFlags: .command)
        XCTAssertTrue(window.tables.staticTexts["Documents"].appeared(timeout: Self.launchTimeout))
    }

    /// Opens Settings at its Templates tab.
    @MainActor
    private func openTemplatesTab(in app: XCUIApplication) -> XCUIElement {
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows[Self.settingsWindow]
        let tab = settings.toolbars.buttons["Templates"]
        XCTAssertTrue(tab.appeared(timeout: Self.launchTimeout), "Settings has Templates")
        tab.click()
        return settings
    }
}
