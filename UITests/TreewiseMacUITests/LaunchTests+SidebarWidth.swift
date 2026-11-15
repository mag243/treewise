import XCTest

/// A window's sidebar starts at its ideal width, and a new window takes the width the user
/// dragged the sidebar to (ADR 0093).
extension LaunchTests {
    /// `SidebarWidth.ideal`, which a UI test's fresh settings have not changed.
    private static let idealSidebar: CGFloat = 260
    /// How far the test drags the divider.
    private static let drag: CGFloat = 60
    /// What a sidebar's width may be off by: its list sits inside it with a little room.
    private static let sidebarSlack: CGFloat = 24
    /// How far past the divider's hairline the test grabs it.
    private static let grip: CGFloat = 2

    @MainActor
    func testANewWindowTakesTheSidebarWidthDraggedTo() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        let sidebar = window.outlines.firstMatch
        XCTAssertEqual(
            sidebar.frame.width, Self.idealSidebar, accuracy: Self.sidebarSlack,
            "a window starts with its sidebar at the ideal width")
        let before = sidebar.frame.width
        let splitter = window.splitters.firstMatch
        XCTAssertTrue(splitter.exists, "the window has a divider")
        // The divider is a hairline; its grip reaches a few points past it.
        let divider = splitter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: Self.grip, dy: 0))
        divider.click(
            forDuration: 0.5, thenDragTo: divider.withOffset(CGVector(dx: Self.drag, dy: 0)))
        XCTAssertTrue(
            app.eventually { sidebar.frame.width > before + Self.drag / 2 },
            "the drag widens it: \(before) to \(sidebar.frame.width), splitter \(splitter.frame)")
        let dragged = sidebar.frame.width
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.eventually { app.windows.count >= 2 }, "a new window opens")
        // Both windows, not whichever is first: the new one may open behind on a narrow screen.
        XCTAssertTrue(
            app.eventually {
                app.windows.allElementsBoundByIndex.allSatisfy {
                    abs($0.outlines.firstMatch.frame.width - dragged) < 2
                }
            }, "the new window takes the width dragged to")
    }
}
