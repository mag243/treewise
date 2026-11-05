import XCTest

/// This Mac, the location that lists the volumes (ADR 0044).
extension LaunchTests {
    @MainActor
    func testThisMacInTheSidebarOpensThisMac() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.launchTimeout))
        app.outlines.staticTexts["This Mac"].click()
        XCTAssertTrue(
            app.windows(titled: "This Mac").firstMatch.waitForExistence(
                timeout: Self.launchTimeout),
            "the window shows This Mac")
        XCTAssertFalse(
            app.menuBarItems["File"].menuItems["New Folder"].isEnabled,
            "nothing is made in This Mac")
    }
}
