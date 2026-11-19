import XCTest

/// Two Treewise windows (ADR 0134): each shows a folder of its own. Dragging between them is
/// checked by hand, as a test cannot place two windows side by side.
final class WindowsTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        // The sidebar stays beside the folder in landscape.
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testOpenInNewWindowShowsTheFolderThereAndLeavesThisWindowAtItsOwn() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

        row("Projects", in: app).press(forDuration: 1)
        app.buttons["Open in New Window"].firstMatch.tap()

        let windows = app.windows
        XCTAssertTrue(
            app.eventually {
                self.window(showing: "Budget.txt", without: "Notes.md", in: windows) != nil
            },
            "a window shows Projects")
        XCTAssertTrue(
            app.eventually { self.window(showing: "Notes.md", without: nil, in: windows) != nil },
            "a window still shows Documents; windows: \(windows.debugDescription)")
    }

    /// The first window that shows an item named `name` and none named `other`.
    @MainActor
    private func window(showing name: String, without other: String?, in windows: XCUIElementQuery)
        -> XCUIElement?
    {
        windows.allElementsBoundByIndex.first { window in
            window.staticTexts[name].exists
                && !(other.map { window.staticTexts[$0].exists } ?? false)
        }
    }
}
