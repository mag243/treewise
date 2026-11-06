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

/// A path that does not fit puts its first folders behind `«` (ADR 0069).
extension LaunchTests {
    @MainActor
    func testANarrowWindowPutsTheFirstFoldersBehindAMenu() throws {
        let deep = ["Quarterly reports of the company", "Second half of the year", "Deepest"]
        let root = try XCTUnwrap(root)
        try FileManager.default.createDirectory(
            at: deep.reduce(root.appendingPathComponent("Projects")) {
                $0.appendingPathComponent($1)
            },
            withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "YES",
            "-TreewiseWindowSize", "640x420",
        ]
        app.launch()
        for name in ["Projects"] + deep {
            let row = app.tables.staticTexts[name]
            XCTAssertTrue(row.waitForExistence(timeout: Self.launchTimeout), "\(name) shows")
            row.doubleClick()
            XCTAssertTrue(
                app.windows(titled: name).firstMatch.waitForExistence(timeout: Self.launchTimeout))
        }

        let above = app.menuButtons["Folders Above"]
        XCTAssertTrue(above.waitForExistence(timeout: Self.launchTimeout), "« shows")
        XCTAssertTrue(app.buttons["Deepest"].isHittable, "the folder shown keeps its place")
        above.click()
        let rootItem = app.menuItems[root.lastPathComponent]
        XCTAssertTrue(rootItem.waitForExistence(timeout: Self.launchTimeout), "« lists the start")
        rootItem.click()
        XCTAssertTrue(
            app.windows(titled: root.lastPathComponent).firstMatch.waitForExistence(
                timeout: Self.launchTimeout),
            "choosing a folder there goes to it")
    }
}
