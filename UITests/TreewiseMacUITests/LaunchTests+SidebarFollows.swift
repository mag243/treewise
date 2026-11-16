import XCTest

/// The sidebar tree follows the folders it shows open, whoever changes them (ADR 0112).
extension LaunchTests {
    @MainActor
    func testAFolderMadeInTreewiseAppearsInTheSidebar() throws {
        let (app, window) = try launchWithTheRootOpenInTheSidebar()
        app.typeKey("n", modifierFlags: [.command, .shift])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            window.outlines.staticTexts["untitled folder"].appeared(timeout: Self.launchTimeout),
            "the new folder shows in the tree")
    }

    @MainActor
    func testAFolderMadeOutsideTreewiseAppearsInTheSidebar() throws {
        let (_, window) = try launchWithTheRootOpenInTheSidebar()
        // The list shows another folder, so only the tree's own watching can see the change.
        window.tables.staticTexts["Projects"].doubleClick()
        XCTAssertTrue(window.outlines.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        try FileManager.default.createDirectory(
            at: try XCTUnwrap(root).appendingPathComponent("Made Elsewhere"),
            withIntermediateDirectories: false)
        XCTAssertTrue(
            window.outlines.staticTexts["Made Elsewhere"].appeared(timeout: Self.launchTimeout),
            "a folder another app makes shows in the tree")
    }

    @MainActor
    func testAFolderGetsADisclosureTriangleOnceAFolderIsMadeInIt() throws {
        let root = try XCTUnwrap(self.root)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Empty"), withIntermediateDirectories: false)
        let (app, window) = try launchWithTheRootOpenInTheSidebar()
        let row = window.outlines.outlineRows.containing(.staticText, identifier: "Empty")
            .firstMatch
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        XCTAssertTrue(app.eventually { !row.disclosureTriangles.firstMatch.exists })
        window.tables.staticTexts["Empty"].doubleClick()
        XCTAssertTrue(window.outlines.staticTexts["Empty"].appeared(timeout: Self.launchTimeout))
        app.typeKey("n", modifierFlags: [.command, .shift])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.eventually { row.disclosureTriangles.firstMatch.exists },
            "the folder now holds a folder to open")
    }

    /// Starts Treewise, goes into Documents and back, so the sidebar opens the root and
    /// the list shows it.
    @MainActor
    private func launchWithTheRootOpenInTheSidebar() throws -> (XCUIApplication, XCUIElement) {
        let app = try launchApp()
        let window = app.windows.firstMatch
        let documents = window.tables.staticTexts["Documents"]
        XCTAssertTrue(documents.appeared(timeout: Self.launchTimeout))
        documents.doubleClick()
        app.typeKey("[", modifierFlags: .command)
        XCTAssertTrue(
            window.outlines.staticTexts["Documents"].appeared(timeout: Self.launchTimeout),
            "the sidebar shows the root's folders")
        XCTAssertTrue(window.tables.staticTexts["Documents"].appeared(timeout: Self.launchTimeout))
        return (app, window)
    }
}
