import XCTest

/// The details pane sits at the window's right from the top of the folder down, and
/// the list takes the rest of the width.
extension LaunchTests {
    /// How far apart two edges may be and still meet.
    private static let edgeTolerance: CGFloat = 2

    @MainActor
    func testTheDetailsPaneSitsBesideTheListAtTheTop() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        let list = window.tables.firstMatch
        XCTAssertTrue(list.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        app.typeKey("p", modifierFlags: [.command, .shift])
        let details = window.groups["Details"]
        XCTAssertTrue(details.appeared(timeout: Self.launchTimeout), "the details pane shows")
        let scroll = list.frame
        let pane = details.frame
        XCTAssertEqual(
            pane.maxX, window.frame.maxX, accuracy: Self.edgeTolerance,
            "the pane ends at the window's right: \(pane) in \(window.frame)")
        // The list's header is above the table's rows, so the pane starts no lower than they do.
        XCTAssertLessThanOrEqual(
            pane.minY, scroll.minY + Self.edgeTolerance,
            "the pane starts at the top of the list: \(pane) beside \(scroll)")
        XCTAssertGreaterThanOrEqual(
            scroll.maxX, pane.minX - Self.edgeTolerance,
            "the list reaches the pane: \(scroll) beside \(pane)")
    }
}
