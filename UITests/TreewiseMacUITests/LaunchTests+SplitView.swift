import XCTest

/// Split View: two folders side by side in one window, ⌘\ to show and hide it, the other
/// side as the other half, and a split window restored split (ADR 0154).
extension LaunchTests {
    /// The narrowest a half's list is expected to be, a little under the app's minimum
    /// half width, which also holds the half's caption and edges.
    private static let halfListMinimum: CGFloat = 250

    /// The captions a split window's halves show; a window that is not split has none.
    @MainActor
    private func captions(in window: XCUIElement) -> XCUIElementQuery {
        window.staticTexts.matching(identifier: "paneCaption")
    }

    /// Whether the window shows two halves, each wide enough to use.
    @MainActor
    private func showsTwoHalves(_ window: XCUIElement) -> Bool {
        window.tables.count == 2
            && (0..<2).allSatisfy {
                window.tables.element(boundBy: $0).frame.width >= Self.halfListMinimum
            }
    }

    /// Splits the window and opens the root's Documents, which is empty, in the right half.
    /// Returns the left and the right half's lists.
    @MainActor
    private func splitWithDocumentsOnTheRight(_ app: XCUIApplication) -> (XCUIElement, XCUIElement)
    {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Documents"].appeared(timeout: Self.launchTimeout))
        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.eventually { self.showsTwoHalves(window) }, "two halves")
        let right = window.tables.element(boundBy: 1)
        right.staticTexts["Documents"].doubleClick()
        XCTAssertTrue(
            app.eventually { !right.staticTexts["Documents"].exists },
            "the right half opens Documents")
        return (window.tables.element(boundBy: 0), right)
    }

    @MainActor
    func testCommandBackslashSplitsTheWindowAndJoinsItAgain() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        XCTAssertEqual(window.tables.count, 1)

        app.typeKey("\\", modifierFlags: .command)

        XCTAssertTrue(app.eventually { self.showsTwoHalves(window) }, "two halves, each usable")
        XCTAssertEqual(captions(in: window).count, 2, "each half names its folder")
        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.eventually { window.tables.count == 1 }, "one half again")
        XCTAssertEqual(captions(in: window).count, 0)
    }

    @MainActor
    func testCopyToOtherSideCopiesIntoTheOtherHalf() throws {
        let root = try XCTUnwrap(self.root)
        let copy = root.appendingPathComponent("Documents/Notes.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
        let app = try launchApp()
        let (left, right) = splitWithDocumentsOnTheRight(app)
        left.staticTexts["Notes.md"].click()

        let edit = app.menuBarItems["Edit"]
        edit.click()
        edit.menuItems["Copy to Other Side"].click()

        XCTAssertTrue(
            app.eventually { FileManager.default.fileExists(atPath: copy.path) },
            "the copy is in the other half's folder")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("Notes.md").path),
            "and the file stays where it was")
        XCTAssertTrue(right.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
    }

    @MainActor
    func testDraggingAFileToTheOtherHalfMovesItAndUndoBringsItBack() throws {
        let root = try XCTUnwrap(self.root)
        let original = root.appendingPathComponent("Notes.md")
        let moved = root.appendingPathComponent("Documents/Notes.md")
        let app = try launchApp()
        let (left, right) = splitWithDocumentsOnTheRight(app)

        left.staticTexts["Notes.md"].press(forDuration: 0.5, thenDragTo: right)

        let files = FileManager.default
        XCTAssertTrue(
            app.eventually {
                files.fileExists(atPath: moved.path) && !files.fileExists(atPath: original.path)
            },
            "on one volume a drag moves")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(
            app.eventually {
                files.fileExists(atPath: original.path) && !files.fileExists(atPath: moved.path)
            },
            "Undo moves it back")
    }

    @MainActor
    func testASplitWindowComesBackSplitAfterARestart() throws {
        let root = try XCTUnwrap(root)
        // Keeping the windows, as a person starts Treewise (ADR 0083).
        let app = XCUIApplication()
        app.launchArguments =
            ["-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "NO"]
            + OpenedLog.arguments(for: root)
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.eventually { self.showsTwoHalves(window) }, "two halves")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout), "Treewise quits")

        app.launch()

        XCTAssertTrue(
            app.eventually { self.showsTwoHalves(app.windows.firstMatch) },
            "the window comes back with two usable halves")
        // No windows are kept for the next launch, so no test starts with these.
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
