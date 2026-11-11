import XCTest

/// The address bar's separators: each opens a menu of the folders inside the
/// folder before it.
extension LaunchTests {
    @MainActor
    func testASeparatorsMenuGoesToAFolderBeside() throws {
        let app = try launchApp()
        let rootName = try rootName
        XCTAssertTrue(
            app.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        app.tables.staticTexts["Projects"].doubleClick()
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(
                timeout: Self.launchTimeout))
        let separator = app.buttons["Folders in \(rootName)"]
        XCTAssertTrue(separator.appeared(timeout: Self.launchTimeout))
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
            app.windows(titled: "Documents").firstMatch.appeared(
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
            XCTAssertTrue(row.appeared(timeout: Self.launchTimeout), "\(name) shows")
            row.doubleClick()
            XCTAssertTrue(
                app.windows(titled: name).firstMatch.appeared(timeout: Self.launchTimeout))
        }

        let above = app.menuButtons["Folders Above"]
        XCTAssertTrue(above.appeared(timeout: Self.launchTimeout), "« shows")
        XCTAssertTrue(app.buttons["Deepest"].isHittable, "the folder shown keeps its place")
        above.click()
        let rootItem = app.menuItems[root.lastPathComponent]
        XCTAssertTrue(rootItem.appeared(timeout: Self.launchTimeout), "« lists the start")
        rootItem.click()
        XCTAssertTrue(
            app.windows(titled: root.lastPathComponent).firstMatch.appeared(
                timeout: Self.launchTimeout),
            "choosing a folder there goes to it")
    }
}

/// A path being typed survives Treewise going to the background and back, as
/// another app's window comes forward for a moment.
extension LaunchTests {
    @MainActor
    func testAPathBeingTypedSurvivesAnotherAppComingForward() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey("l", modifierFlags: .command)
        let field = app.textFields["Address"]
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "⌘L shows the field")
        app.typeKey("a", modifierFlags: .command)
        let path = try XCTUnwrap(root).appendingPathComponent("Projects").path + "/"
        let half = path.index(path.startIndex, offsetBy: path.count / 2)
        type(String(path[..<half]), in: app)
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        app.activate()
        type(String(path[half...]), in: app)
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(timeout: Self.launchTimeout),
            "the typing goes on in the field, and Return goes there")
    }

    /// Types `text` one key at a time, as a person types.
    @MainActor
    private func type(_ text: String, in app: XCUIApplication) {
        for character in text {
            let key = String(character)
            let isUpper = key != key.lowercased()
            app.typeKey(key.lowercased(), modifierFlags: isUpper ? .shift : [])
        }
    }
}

/// The path sits in the middle of the address bar, its folders and separators on one line.
extension LaunchTests {
    /// How far apart two middles may be and still look level.
    private static let levelTolerance: CGFloat = 1

    @MainActor
    func testThePathSitsInTheMiddleOfTheAddressBar() throws {
        let app = try launchApp()
        let rootName = try rootName
        XCTAssertTrue(
            app.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        app.tables.staticTexts["Projects"].doubleClick()
        let window = app.windows(titled: "Projects").firstMatch
        XCTAssertTrue(window.appeared(timeout: Self.launchTimeout))
        let bar = window.buttons["Type a path"]
        let folder = window.buttons["Projects"]
        let separator = window.buttons["Folders in \(rootName)"]
        XCTAssertTrue(separator.appeared(timeout: Self.launchTimeout))
        let middle = bar.frame.midY
        for (name, element) in [("folder", folder), ("separator", separator)] {
            XCTAssertEqual(
                element.frame.midY, middle, accuracy: Self.levelTolerance,
                "the \(name) sits in the middle of the bar: \(element.frame) in \(bar.frame)")
        }
    }
}
