import XCTest

/// Changing a zip from the window (ADR 0078), each with its undo.
extension LaunchTests {
    /// A zip that holds `inside.txt`, stored without compression.
    private static let zip =
        "UEsDBBQAAAAAAGV4aV2m38+IEAAAABAAAAAKAAAAaW5zaWRlLnR4dGZyb20gdGhlIGFyY2hpdmVQSwECFAMUAAAAAABleGldpt/PiBAAAAAQAAAACgAAAAAAAAAAAAAAgAEAAAAAaW5zaWRlLnR4dFBLBQYAAAAAAQABADgAAAA4AAAAAAA="
    private static let hold: TimeInterval = 0.6

    /// Opens the fixture's zip; returns the app, its window and the zip's file.
    @MainActor
    private func openZip() throws -> (XCUIApplication, XCUIElement) {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.zip))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let row = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        row.doubleClick()
        XCTAssertTrue(window.tables.staticTexts["inside.txt"].appeared(timeout: Self.launchTimeout))
        return (app, window)
    }

    @MainActor
    private func drag(_ source: XCUIElement, onto target: XCUIElement) {
        let centre = CGVector(dx: 0.5, dy: 0.5)
        source.coordinate(withNormalizedOffset: centre).click(
            forDuration: Self.hold,
            thenDragTo: target.coordinate(withNormalizedOffset: centre),
            withVelocity: .slow, thenHoldForDuration: Self.hold)
    }

    /// Waits for the Edit menu to offer an undo. A name typed into its field
    /// shows before the archive has changed; this shows that it has.
    @MainActor
    func waitUntilUndoable(_ title: String, in app: XCUIApplication) {
        let edit = app.menuBars.menuBarItems["Edit"]
        let deadline = Date().addingTimeInterval(Self.launchTimeout)
        var shown = ""
        repeat {
            edit.click()
            shown = edit.menuItems.element(boundBy: 0).title
            app.typeKey(.escape, modifierFlags: [])
        } while shown != title && Date() < deadline
        XCTAssertEqual(shown, title, "the change is done")
    }

    @MainActor
    private func assertShows(_ name: String, in window: XCUIElement, _ message: String) {
        XCTAssertTrue(
            window.tables.staticTexts[name].appeared(timeout: Self.launchTimeout), message)
    }

    @MainActor
    private func assertGone(_ name: String, in window: XCUIElement, _ message: String) {
        XCTAssertTrue(
            window.tables.staticTexts[name].disappeared(timeout: Self.launchTimeout), message)
    }

    @MainActor
    func testRenamingInAZipAndUndo() throws {
        let (app, window) = try openZip()
        window.tables.staticTexts["inside.txt"].click()

        app.typeKey(.return, modifierFlags: [])
        let field = window.tables.textFields.firstMatch
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "renaming starts")
        field.typeText("renamed\r")

        assertShows("renamed.txt", in: window, "the entry has its new name")
        assertGone("inside.txt", in: window, "the old name is gone")
        waitUntilUndoable("Undo Rename", in: app)
        app.typeKey("z", modifierFlags: .command)
        assertShows("inside.txt", in: window, "undo brings the old name back")
    }

    @MainActor
    func testANewFolderInAZipAndUndo() throws {
        let (app, window) = try openZip()

        app.typeKey("n", modifierFlags: [.command, .shift])
        let field = window.tables.textFields.firstMatch
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "renaming starts")
        field.typeText("Fresh\r")

        assertShows("Fresh", in: window, "the folder has its name")
        waitUntilUndoable("Undo Rename", in: app)
        app.typeKey("z", modifierFlags: .command)
        assertGone("Fresh", in: window, "undo takes its name away")
        assertShows("untitled folder", in: window, "the new folder is left")
        app.typeKey("z", modifierFlags: .command)
        assertGone("untitled folder", in: window, "undo takes the folder away")
    }

    @MainActor
    func testDeletingInAZipAndUndo() throws {
        let (app, window) = try openZip()
        window.tables.staticTexts["inside.txt"].click()

        app.typeKey(.delete, modifierFlags: .command)

        assertGone("inside.txt", in: window, "the entry is gone")
        app.typeKey("z", modifierFlags: .command)
        assertShows("inside.txt", in: window, "undo brings it back")
    }

    @MainActor
    func testCopyingWithinAZip() throws {
        let (app, window) = try openZip()
        window.tables.staticTexts["inside.txt"].click()

        app.typeKey("c", modifierFlags: .command)
        app.typeKey("v", modifierFlags: .command)

        assertShows("inside copy.txt", in: window, "the copy is beside it")
        assertShows("inside.txt", in: window, "the original stays")
    }

    @MainActor
    func testMovingIntoAFolderOfAZipAndUndo() throws {
        let (app, window) = try openZip()
        app.typeKey("n", modifierFlags: [.command, .shift])
        let field = window.tables.textFields.firstMatch
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "renaming starts")
        field.typeText("Box\r")
        assertShows("Box", in: window, "the folder is there")
        // The list is read again when the rename ends, which would move the rows mid-drag.
        waitUntilUndoable("Undo Rename", in: app)

        drag(window.tables.staticTexts["inside.txt"], onto: window.tables.staticTexts["Box"])

        assertGone("inside.txt", in: window, "the entry left this folder")
        window.tables.staticTexts["Box"].doubleClick()
        assertShows("inside.txt", in: window, "the entry is in the folder")
        app.typeKey("z", modifierFlags: .command)
        assertGone("inside.txt", in: window, "undo takes it out of the folder")
    }

    @MainActor
    func testDraggingAFileOntoAZipInTheSidebar() throws {
        let (app, window) = try openZip()
        app.typeKey("[", modifierFlags: .command)
        let notes = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        let row = window.outlines.staticTexts["Photos.zip"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout), "the sidebar shows the zip")

        drag(notes, onto: row)

        XCTAssertTrue(notes.exists, "the file stays where it was")
        // Opened while the change may still run: the list follows when it ends.
        window.tables.staticTexts["Photos.zip"].doubleClick()
        assertShows("Notes.md", in: window, "a copy is in the zip")
    }
}
