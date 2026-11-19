import XCTest

/// The list in a narrow window: the name stays within the window, as the columns beside it
/// that the user did not choose take no room (ADR 0127).
extension LaunchTests {
    @MainActor
    func testTheNameColumnFitsANarrowWindow() throws {
        let root = try XCTUnwrap(root)
        let app = XCUIApplication()
        app.launchArguments =
            [
                "-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "YES",
                "-TreewiseWindowSize", "640x420",
            ] + OpenedLog.arguments(for: root)
        app.launch()
        let window = app.windows.firstMatch
        let notes = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        XCTAssertLessThanOrEqual(
            notes.frame.maxX, window.frame.maxX,
            "the name column ends inside the window, not under what lies beside it")
    }
}
