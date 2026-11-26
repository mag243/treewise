import XCTest

/// Split View: two folders side by side in one window, ⌘\ to show and hide it, the other
/// side as the other half, and a split window restored split (ADR 0154).
extension LaunchTests {
    /// The captions a split window's halves show; a window that is not split has none.
    @MainActor
    private func captions(in window: XCUIElement) -> XCUIElementQuery {
        window.staticTexts.matching(identifier: "paneCaption")
    }

    @MainActor
    func testCommandBackslashSplitsTheWindowAndJoinsItAgain() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        XCTAssertEqual(window.tables.count, 1)

        app.typeKey("\\", modifierFlags: .command)

        XCTAssertTrue(app.eventually { window.tables.count == 2 }, "two halves")
        XCTAssertEqual(captions(in: window).count, 2, "each half names its folder")
        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.eventually { window.tables.count == 1 }, "one half again")
        XCTAssertEqual(captions(in: window).count, 0)
    }

    @MainActor
    func testCopyToOtherSideCopiesIntoTheOtherHalf() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Documents"].appeared(timeout: Self.launchTimeout))
        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.eventually { window.tables.count == 2 }, "two halves")
        // The right half has the focus and opens Documents.
        window.tables.element(boundBy: 1).staticTexts["Documents"].doubleClick()
        let right = window.tables.containing(.staticText, identifier: "Taxes").firstMatch
        XCTAssertTrue(right.appeared(timeout: Self.launchTimeout), "the right half shows Documents")
        let left = window.tables.containing(.staticText, identifier: "Notes.md").firstMatch
        left.staticTexts["Notes.md"].click()

        let edit = app.menuBarItems["Edit"]
        edit.click()
        edit.menuItems["Copy to Other Side"].click()

        XCTAssertTrue(
            right.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout),
            "the copy is in the other half's folder")
        XCTAssertTrue(left.staticTexts["Notes.md"].exists, "and the file stays where it was")
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
        XCTAssertTrue(app.eventually { window.tables.count == 2 }, "two halves")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout), "Treewise quits")

        app.launch()

        XCTAssertTrue(
            app.eventually { app.windows.firstMatch.tables.count == 2 },
            "the window comes back with two halves")
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
