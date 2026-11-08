import XCTest

/// Starts the app confined to a temporary folder (`-TreewiseRoot`), so the
/// test never shows or touches the user's own folders.
final class LaunchTests: XCTestCase {
    static let launchTimeout: TimeInterval = 10

    private(set) var root: URL?

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreewiseUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("Projects"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: folder.appendingPathComponent("Notes.md"))
        root = folder
    }

    override func tearDownWithError() throws {
        if let root { try FileManager.default.removeItem(at: root) }
    }

    /// Starts the app in the temporary root without restoring windows, so the
    /// "reopen windows?" question after an earlier crash cannot block the test.
    @MainActor
    func launchApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseRoot", try XCTUnwrap(root).path, "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testLaunchListsTheStartFolder() throws {
        let app = try launchApp()
        XCTAssertTrue(app.windows.firstMatch.appeared(timeout: Self.launchTimeout))
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        XCTAssertTrue(app.tables.staticTexts["Projects"].exists)
        XCTAssertTrue(
            app.outlines.staticTexts["Documents"].exists,
            "the sidebar lists Documents as a favorite")
        XCTAssertTrue(app.outlines.staticTexts["This Mac"].exists, "Locations start at This Mac")
    }

    @MainActor
    func testStaysInsideTheFolderItWasStartedIn() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        XCTAssertFalse(
            app.toolbars.buttons["Enclosing Folder"].isEnabled,
            "the root is the top of the boundary (ADR 0019)")
    }

    /// Opens a window beside the first with ⌥⌘N and waits until there are two.
    /// Both show the root folder; a test tells them apart by what they show
    /// next, since clicking one changes which comes first.
    @MainActor
    func openWindowBeside(in app: XCUIApplication) {
        app.typeKey("n", modifierFlags: [.command, .option])
        XCTAssertTrue(app.eventually { app.windows.count == 2 }, "a second window opens")
    }

    @MainActor
    func testCommandNOpensASecondWindow() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey("n", modifierFlags: .command)
        let second = app.windows.element(boundBy: 1)
        XCTAssertTrue(second.appeared(timeout: Self.launchTimeout), "a second window opens")
        XCTAssertEqual(app.state, .runningForeground, "and Treewise keeps running")
    }

    /// The name of the root folder, which is the title of a window showing it.
    var rootName: String {
        get throws { try XCTUnwrap(root).lastPathComponent }
    }

    @MainActor
    func testCommandWClosesTheTabBeforeTheWindow() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        XCTAssertTrue(app.waitForNewTab())
        app.typeKey("t", modifierFlags: .command)
        XCTAssertTrue(app.waitForSecondTab(), "⌘T opens a window tab (ADR 0037)")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.exists, "⌘W closed the new tab, not the window")

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(
            app.windows.firstMatch.disappeared(timeout: Self.launchTimeout),
            "⌘W on the last tab closes the window")
    }

    @MainActor
    func testContextMenuOpensAFolderInANewTab() throws {
        let app = try launchApp()
        let projects = app.tables.staticTexts["Projects"]
        XCTAssertTrue(projects.appeared(timeout: Self.launchTimeout))
        projects.rightClick()
        app.menuItems["Open in New Tab"].click()
        XCTAssertTrue(app.waitForSecondTab(), "a window tab opens")
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(
                timeout: Self.launchTimeout),
            "the new tab shows Projects")
    }

    @MainActor
    func testSpaceShowsQuickLook() throws {
        let app = try launchApp()
        let notes = app.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        notes.click()
        XCTAssertEqual(app.windows.count, 1)
        app.typeKey(" ", modifierFlags: [])
        let panel = app.windows.element(boundBy: 1)
        XCTAssertTrue(panel.appeared(timeout: Self.launchTimeout), "the Quick Look panel")
    }

    @MainActor
    func testCommandDownOpensAFolderAndCommandUpGoesBack() throws {
        let app = try launchApp()
        let projects = app.tables.staticTexts["Projects"]
        XCTAssertTrue(projects.appeared(timeout: Self.launchTimeout))
        projects.click()
        app.typeKey(.downArrow, modifierFlags: .command)
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].disappeared(timeout: Self.launchTimeout),
            "⌘↓ opens the empty Projects folder")
        app.typeKey(.upArrow, modifierFlags: .command)
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout),
            "⌘↑ goes back to the enclosing folder")
    }

    @MainActor
    func testOptionCommandDownOpensInTheOtherWindow() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        openWindowBeside(in: app)
        app.windows.firstMatch.tables.staticTexts["Projects"].click()
        app.typeKey(.downArrow, modifierFlags: [.command, .option])
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(
                timeout: Self.launchTimeout),
            "the other window shows Projects")
        XCTAssertTrue(
            app.windows(titled: try rootName).firstMatch.tables.staticTexts["Notes.md"].exists,
            "the window it was opened from stays where it was")
        XCTAssertEqual(app.windows.count, 2, "no third window")
    }

    @MainActor
    func testClickingEmptySpaceMakesTheWindowActive() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        openWindowBeside(in: app)
        app.windows.firstMatch.tables.staticTexts["Projects"].doubleClick()
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(
                timeout: Self.launchTimeout),
            "one window shows the empty Projects folder")
        app.windows(titled: try rootName).firstMatch.tables.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).click()
        app.typeKey("n", modifierFlags: [.command, .shift])
        // The new folder starts being renamed, so its name is in a text field: look on disk.
        let root = try XCTUnwrap(root)
        let made = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                FileManager.default.fileExists(
                    atPath: root.appendingPathComponent("untitled folder").path)
            }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [made], timeout: Self.launchTimeout), .completed,
            "the new folder lands in the folder of the window whose empty space was clicked")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Projects/untitled folder").path),
            "not in the folder of the other window")
    }

    /// A button of the command bar, in the window in front (ADR 0037).
    @MainActor
    private func commandBarButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.windows.firstMatch.buttons[name].firstMatch
    }

    @MainActor
    func testCommandBarCopyAndPasteMakeACopy() throws {
        let app = try launchApp()
        let notes = app.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        notes.click()
        commandBarButton("Copy", in: app).click()
        let paste = commandBarButton("Paste", in: app)
        XCTAssertTrue(paste.isEnabled, "Paste follows the clipboard")
        paste.click()
        XCTAssertTrue(
            app.tables.staticTexts["Notes copy.md"].appeared(timeout: Self.launchTimeout),
            "pasting into the same folder keeps both")
    }

    @MainActor
    func testTypingAPathInTheAddressBarGoesThere() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey("l", modifierFlags: .command)
        let field = app.textFields["Address"]
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "⌘L shows the field")
        app.typeKey("a", modifierFlags: .command)
        // With the slash nothing is left to suggest, so Return goes instead of
        // taking a suggestion; Projects is empty. One key at a time, as a
        // person types: typeText dropped the first "c" of "Projects".
        for character in try XCTUnwrap(root).appendingPathComponent("Projects").path + "/" {
            let key = String(character)
            let isUpper = key != key.lowercased()
            app.typeKey(key.lowercased(), modifierFlags: isUpper ? .shift : [])
        }
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.windows(titled: "Projects").firstMatch.appeared(
                timeout: Self.launchTimeout),
            "the window shows Projects (the field holds \(field.value as? String ?? ""))")
        XCTAssertFalse(field.exists, "and the address bar shows the path again")
    }

    @MainActor
    func testTheStatusBarButtonsSwitchBetweenIconsAndList() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        // A segment is a radio button or a button, depending on the macOS version.
        let window = app.windows.firstMatch
        window.descendants(matching: .any)["as Icons"].firstMatch.click()
        XCTAssertTrue(
            app.collectionViews.staticTexts["Notes.md"].appeared(
                timeout: Self.launchTimeout), "the icons button shows the items as icons")
        window.descendants(matching: .any)["as List"].firstMatch.click()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout),
            "the list button shows the list again")
    }

    @MainActor
    func testCommandOneAndTwoSwitchBetweenIconsAndList() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            app.collectionViews.staticTexts["Notes.md"].appeared(
                timeout: Self.launchTimeout), "⌘1 shows the items as icons")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout),
            "⌘2 shows the list again")
    }
}
