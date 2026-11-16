import XCTest

/// The sidebar brings the folder shown into its middle when it is out of view, also after
/// a restart, and leaves the tree where it is when the folder is already in view.
extension LaunchTests {
    /// Enough folders beside each other that the tree scrolls in any window.
    private static let manyFolders = 60
    private static let deepFolder = "Folder 50"

    @MainActor
    func testAFolderOutOfViewInTheSidebarComesToItsMiddleAfterARestart() throws {
        let root = try XCTUnwrap(root)
        try makeManyFolders(in: root)
        let app = XCUIApplication()
        app.launchArguments =
            ["-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "NO"]
            + OpenedLog.arguments(for: root)
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.appeared(timeout: Self.launchTimeout))
        app.go(to: Self.deepFolder, timeout: Self.launchTimeout)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout), "Treewise quits")

        app.launch()
        let window = app.windows(titled: Self.deepFolder).firstMatch
        XCTAssertTrue(window.appeared(timeout: Self.launchTimeout), "the folder comes back")
        let row = window.outlines.staticTexts[Self.deepFolder]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        XCTAssertTrue(
            app.eventually { Self.isInTheMiddle(row, of: window) },
            "the row at \(row.frame) is in the middle third of the window at \(window.frame)")
        closeEveryWindowAndQuit(app)
    }

    @MainActor
    func testAFolderInViewInTheSidebarStaysWhereItIs() throws {
        let root = try XCTUnwrap(root)
        try makeManyFolders(in: root)
        let app = try launchApp()
        let window = app.windows.firstMatch
        let documents = window.tables.staticTexts["Documents"]
        XCTAssertTrue(documents.appeared(timeout: Self.launchTimeout))
        documents.doubleClick()
        app.typeKey("[", modifierFlags: .command)
        // Near the top of the tree, in view without scrolling; Documents is a favorite too.
        let row = window.outlines.staticTexts["Folder 02"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        let before = row.frame
        row.click()
        XCTAssertTrue(
            app.windows(titled: "Folder 02").firstMatch.appeared(timeout: Self.launchTimeout))
        // A selected row's text may be drawn a little wider; only its height in the tree counts.
        XCTAssertEqual(
            row.frame.minY, before.minY, "choosing a row in view does not scroll the tree")
    }

    private func makeManyFolders(in root: URL) throws {
        for number in 1...Self.manyFolders {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(String(format: "Folder %02d", number)),
                withIntermediateDirectories: false)
        }
    }

    /// Whether the row's middle lies in the middle third of the window's height.
    @MainActor
    private static func isInTheMiddle(_ row: XCUIElement, of window: XCUIElement) -> Bool {
        let third = window.frame.height / 3
        let middle = row.frame.midY
        return middle > window.frame.minY + third && middle < window.frame.maxY - third
    }

    /// No windows are kept for the next launch, so no test starts with these.
    @MainActor
    private func closeEveryWindowAndQuit(_ app: XCUIApplication) {
        XCTAssertTrue(
            app.eventually {
                let window = app.windows.firstMatch
                if window.exists { app.typeKey("w", modifierFlags: .command) }
                return !window.exists
            }, "every window closes")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout))
    }
}
