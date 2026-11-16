import AppKit
import XCTest

/// A test run opens its windows on the main display, the one with the menu bar, whichever
/// display the user works on: XCTest cannot take a screenshot of a window on another one.
extension LaunchTests {
    @MainActor
    func testATestRunOpensItsWindowsOnTheMainDisplay() throws {
        let app = try launchApp()
        let browser = app.windows.firstMatch
        XCTAssertTrue(browser.appeared(timeout: Self.launchTimeout))
        assertOnMainDisplay(browser, "the browser window")
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows["TreewiseSettings"]
        XCTAssertTrue(settings.appeared(timeout: Self.launchTimeout))
        assertOnMainDisplay(settings, "Settings")
        app.menuBarItems["Treewise"].menuItems["About Treewise"].click()
        let about = app.dialogs.firstMatch
        XCTAssertTrue(about.appeared(timeout: Self.launchTimeout))
        assertOnMainDisplay(about, "About Treewise")
    }

    /// XCTest gives frames with the main display's top left at zero.
    @MainActor
    private func assertOnMainDisplay(_ window: XCUIElement, _ name: String) {
        guard let main = NSScreen.screens.first else { return }
        let display = CGRect(origin: .zero, size: main.frame.size)
        XCTAssertTrue(
            display.contains(window.frame),
            "\(name) at \(window.frame) lies on the main display \(display)")
    }
}
