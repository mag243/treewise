import XCTest

/// The address bar's separators: each opens a menu of the folders inside the
/// folder before it.
extension LaunchTests {
    @MainActor
    func testASeparatorsMenuGoesToAFolderBeside() throws {
        let app = try launchApp()
        let rootName = try rootName
        XCTAssertTrue(
            app.tables.staticTexts["Projects"].waitForExistence(timeout: Self.launchTimeout))
        app.tables.staticTexts["Projects"].doubleClick()
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.waitForExistence(
                timeout: Self.launchTimeout))
        let separator = app.buttons["Folders in \(rootName)"]
        XCTAssertTrue(separator.waitForExistence(timeout: Self.launchTimeout))
        separator.click()
        // The menu bar has a Documents item too; the separator's menu is the
        // one on screen.
        var documents: XCUIElement?
        XCTAssertTrue(
            app.eventually {
                documents = app.menuItems.matching(identifier: "Documents")
                    .allElementsBoundByIndex.first(where: \.isHittable)
                return documents != nil
            }, "the menu lists the folders beside Projects")
        try XCTUnwrap(documents).click()
        XCTAssertTrue(
            app.windows(titled: "Documents").firstMatch.waitForExistence(
                timeout: Self.launchTimeout),
            "choosing one goes there")
    }
}
