import XCTest

/// Waiting for what AppKit does a moment after a key or a click, and finding
/// windows by the folder they show, for the UI tests.
extension XCUIApplication {
    /// How long a test waits for the app before it fails.
    static let waitTimeout: TimeInterval = 10
    /// How long `eventually` waits between two checks.
    private static let pollInterval: TimeInterval = 0.25

    /// Checks `condition` until it holds, up to `waitTimeout`.
    @MainActor
    func eventually(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(Self.waitTimeout)
        while !condition() {
            guard Date() < deadline else { return false }
            let pause = XCTestExpectation(description: "pause")
            _ = XCTWaiter.wait(for: [pause], timeout: Self.pollInterval)
        }
        return true
    }

    /// Waits until the window in front has two tabs in its tab bar.
    @MainActor
    func waitForSecondTab() -> Bool {
        eventually { tabGroups.firstMatch.tabs.count >= 2 }
    }

    /// Waits until File > New Tab can be chosen: just after launch the window
    /// may not have handed its actions to the menu bar yet, and ⌘T then does
    /// nothing. The menu is opened, as AppKit enables an item when it opens.
    @MainActor
    func waitForNewTab() -> Bool {
        let menu = menuBarItems["File"]
        let newTab = menu.menuItems["New Tab"]
        return eventually {
            menu.click()
            let enabled = newTab.waitForExistence(timeout: Self.waitTimeout) && newTab.isEnabled
            typeKey(.escape, modifierFlags: [])
            return enabled
        }
    }

    /// The windows whose title is `title`, the name of the folder they show.
    @MainActor
    func windows(titled title: String) -> XCUIElementQuery {
        windows.matching(NSPredicate(format: "title == %@", title))
    }
}
