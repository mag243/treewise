import XCTest

/// The iPad app with only a keyboard (ADR 0135): the arrows move the selection, and the Mac's
/// keys open, copy, paste and go through the folders. ↩, ⌘⌫, ⌘F and ⌃⌘S are not here: the
/// simulator does not deliver them to the app under XCUITest. The fixture's Documents holds, in
/// order, Archive, Projects, Budget.txt and Notes.md.
final class KeyboardTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    private static let down = XCUIKeyboardKey.downArrow.rawValue
    private static let up = XCUIKeyboardKey.upArrow.rawValue

    override func setUp() async throws {
        continueAfterFailure = false
        // The sidebar stays beside the folder in landscape.
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func openDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        // The sidebar has the keyboard after a tap in it, as on the Mac; a tap on empty space
        // below the rows gives it to the list.
        app.descendants(matching: .any)["folderTable"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        return app
    }

    /// Presses an arrow and waits until it selected `name`.
    @MainActor
    private func arrow(_ key: String, selecting name: String, in app: XCUIApplication) {
        app.typeKey(key, modifierFlags: [])
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(app.eventually { cell.isSelected }, "\(name) selected")
    }

    @MainActor
    func testCommandDownOpensAndTheGoKeysMoveThroughTheFolders() {
        let app = openDocuments()
        arrow(Self.down, selecting: "Archive", in: app)
        arrow(Self.down, selecting: "Projects", in: app)
        app.typeKey(Self.down, modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: Self.timeout))

        app.typeKey(Self.up, modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: Self.timeout))
        app.typeKey("[", modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: Self.timeout))
        app.typeKey("]", modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testCopyAndPasteWithTheKeys() {
        let app = openDocuments()
        arrow(Self.up, selecting: "Notes.md", in: app)
        app.typeKey("c", modifierFlags: .command)
        arrow(Self.up, selecting: "Budget.txt", in: app)
        arrow(Self.up, selecting: "Projects", in: app)
        arrow(Self.up, selecting: "Archive", in: app)
        app.typeKey(Self.down, modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Archive"].waitForExistence(timeout: Self.timeout))

        app.typeKey("v", modifierFlags: .command)
        XCTAssertTrue(
            row("Notes.md", in: app).waitForExistence(timeout: Self.timeout), "pasted in Archive")
    }

}
