import XCTest

/// This Mac, the location that lists the volumes (ADR 0044).
extension LaunchTests {
    @MainActor
    func testTheHomeFolderShowsAHouseInTheSidebar() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.outlines.images["Home"].appeared(timeout: Self.launchTimeout),
            "the home folder has the house")
    }

    @MainActor
    func testThisMacInTheSidebarOpensThisMac() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.outlines.staticTexts["This Mac"].click()
        XCTAssertTrue(
            app.windows(titled: "This Mac").firstMatch.appeared(
                timeout: Self.launchTimeout),
            "the window shows This Mac")
        // The menu follows the window a moment after its title does.
        let newFolder = app.menuBarItems["File"].menuItems["New Folder"]
        XCTAssertTrue(app.eventually { !newFolder.isEnabled }, "nothing is made in This Mac")
    }
}
