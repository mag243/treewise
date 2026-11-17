import XCTest

/// The list headers' menu shows the dates created and added only once chosen, as Finder's
/// does (ADR 0127).
extension LaunchTests {
    @MainActor
    func testTheHeadersMenuShowsTheDateCreatedOnceChosen() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        let table = window.tables.firstMatch
        XCTAssertTrue(table.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        let size = table.buttons["Size"]
        XCTAssertTrue(size.exists, "the Size header")
        XCTAssertFalse(table.buttons["Date Created"].exists, "hidden at first")

        size.rightClick()
        let item = app.menuItems["Date Created"]
        XCTAssertTrue(item.appeared(timeout: Self.launchTimeout), "the headers' menu")
        item.click()

        XCTAssertTrue(
            table.buttons["Date Created"].appeared(timeout: Self.launchTimeout), "shown")
    }
}
