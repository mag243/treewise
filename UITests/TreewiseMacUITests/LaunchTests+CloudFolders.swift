import XCTest

/// A cloud folder stays where it is, named as it is (ADR 0049). In the temporary
/// root a folder named Nextcloud is one, because the root is the home folder.
extension LaunchTests {
    /// How long a click on a name may take to start renaming: longer than
    /// the double-click interval it waits for.
    private static let renameWait: TimeInterval = 2
    /// Where in a row's name to click: on its first letters, not the empty
    /// rest of the field.
    private static let onTheName = CGVector(dx: 0.1, dy: 0.5)

    /// Starts the app with a cloud folder in its root.
    @MainActor
    private func launchWithCloudFolder() throws -> XCUIApplication {
        try FileManager.default.createDirectory(
            at: try XCTUnwrap(root).appendingPathComponent("Nextcloud"),
            withIntermediateDirectories: true)
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Nextcloud"].appeared(timeout: Self.launchTimeout))
        return app
    }

    /// Whether File > Rename and Edit > Move to Trash are enabled, after the
    /// menu had the time to follow the selection.
    @MainActor
    private func expectMenus(in app: XCUIApplication, enabled: Bool, _ message: String) {
        let rename = app.menuBarItems["File"].menuItems["Rename"]
        let trash = app.menuBarItems["Edit"].menuItems["Move to Trash"]
        XCTAssertTrue(
            app.eventually { rename.isEnabled == enabled && trash.isEnabled == enabled }, message)
    }

    @MainActor
    func testTheMenusOfferNoRenameOrTrashForACloudFolder() throws {
        let app = try launchWithCloudFolder()
        app.tables.staticTexts["Documents"].click()
        expectMenus(in: app, enabled: true, "a plain folder can be renamed and trashed")
        app.tables.staticTexts["Nextcloud"].click()
        expectMenus(in: app, enabled: false, "a cloud folder cannot")
    }

    @MainActor
    func testTheCommandBarOffersNoChangesForACloudFolder() throws {
        let app = try launchWithCloudFolder()
        let names = ["Cut", "Copy", "Rename", "Move to Trash"]
        let buttons = names.map { app.windows.firstMatch.buttons[$0].firstMatch }
        app.tables.staticTexts["Documents"].click()
        XCTAssertTrue(
            app.eventually { buttons.allSatisfy(\.isEnabled) }, "a plain folder can be changed")
        app.tables.staticTexts["Nextcloud"].click()
        XCTAssertTrue(
            app.eventually { !buttons.contains(where: \.isEnabled) }, "a cloud folder cannot")
    }

    @MainActor
    func testTheContextMenuOffersNoRenameOrTrashForACloudFolder() throws {
        let app = try launchWithCloudFolder()
        app.tables.staticTexts["Nextcloud"].rightClick()
        let menu = app.tables.menus.firstMatch
        XCTAssertTrue(menu.appeared(timeout: Self.launchTimeout))
        XCTAssertFalse(menu.menuItems["Rename"].isEnabled)
        XCTAssertFalse(menu.menuItems["Move to Trash"].isEnabled)
        XCTAssertFalse(menu.menuItems["Cut"].isEnabled)
        XCTAssertFalse(menu.menuItems["Copy"].isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testClickingACloudFoldersNameDoesNotRenameIt() throws {
        let app = try launchWithCloudFolder()
        // Selected with the keyboard, so the click on the name is a single
        // click; the folders sort as Documents, Nextcloud, Projects.
        app.tables.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        let name = app.tables.staticTexts["Nextcloud"]
        name.coordinate(withNormalizedOffset: Self.onTheName).click()
        XCTAssertFalse(
            app.tables.textFields.firstMatch.appeared(timeout: Self.renameWait),
            "a click on the selected name of a cloud folder starts no rename")
    }
}
