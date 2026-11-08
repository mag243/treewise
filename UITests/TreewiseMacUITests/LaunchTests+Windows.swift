import AppKit
import XCTest

/// Two windows side by side (ADR 0037).
extension LaunchTests {
    /// The narrowest window, `WindowWidths.windowMinimum` in the app.
    private static let windowMinimum: CGFloat = 620

    @MainActor
    func testWindowBesidePutsTwoWindowsSideBySide() throws {
        let app = try launchApp()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        openWindowBeside(in: app)
        let first = app.windows.element(boundBy: 0)
        let second = app.windows.element(boundBy: 1)
        // XCUITest and AppKit share the x axis, so the window's midpoint finds its screen.
        XCTAssertTrue(first.appeared(timeout: Self.launchTimeout))
        let screen = try XCTUnwrap(
            NSScreen.screens.first { $0.frame.minX...$0.frame.maxX ~= first.frame.midX }
        ).visibleFrame
        if screen.width >= 2 * Self.windowMinimum {
            XCTAssertTrue(
                app.eventually {
                    first.frame.maxX <= second.frame.minX || second.frame.maxX <= first.frame.minX
                }, "the two windows end up side by side, not overlapping")
        } else {
            // Two windows of the minimum width overlap on a narrow screen,
            // such as a CI runner's: each goes against its own edge.
            XCTAssertTrue(
                app.eventually {
                    let frames = [first.frame, second.frame].sorted { $0.minX < $1.minX }
                    return frames[0].minX == screen.minX && frames[1].maxX == screen.maxX
                        && frames.allSatisfy { $0.width >= Self.windowMinimum }
                }, "on a narrow screen the windows go against the left and right edges")
        }
        XCTAssertEqual(
            app.windows(titled: try rootName).count, 2,
            "both show the same folder")
    }
}
