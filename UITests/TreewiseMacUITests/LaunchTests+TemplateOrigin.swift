import XCTest

extension LaunchTests {
    /// A folder made from a template says so in the details pane, and Forget takes it off
    /// (ADR 0141).
    @MainActor
    func testAFolderMadeFromATemplateSaysSoUntilForgotten() throws {
        try makeClientFolder()
        let app = try launchApp()
        try saveClientTemplate(in: app)
        let window = app.windows.firstMatch
        window.tables.staticTexts["Documents"].rightClick()
        let menu = window.tables.menus.submenuItem(
            "New Folders from Template", in: "Folder Structure")
        XCTAssertTrue(menu.appeared(timeout: Self.launchTimeout))
        menu.hover()
        menu.menuItems[Self.client].click()
        let create = window.sheets.firstMatch.buttons["Create Folders"]
        XCTAssertTrue(create.appeared(timeout: Self.launchTimeout))
        create.click()
        XCTAssertTrue(window.staticTexts["Made 3 folders."].appeared(timeout: Self.launchTimeout))
        window.tables.staticTexts["Documents"].doubleClick()
        let made = window.tables.staticTexts[Self.client]
        XCTAssertTrue(made.appeared(timeout: Self.launchTimeout))
        made.click()
        app.typeKey("p", modifierFlags: [.command, .shift])
        let details = window.groups["Details"]
        XCTAssertTrue(
            details.staticTexts["Made from"].appeared(timeout: Self.launchTimeout),
            "the details pane says which template made it")
        details.buttons["Forget “\(Self.client)”"].click()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: details.staticTexts["Made from"])
        XCTAssertEqual(
            XCTWaiter.wait(for: [gone], timeout: Self.launchTimeout), .completed,
            "Forget takes it off")
    }
}
