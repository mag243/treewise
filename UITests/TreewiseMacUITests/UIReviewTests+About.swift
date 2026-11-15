import XCTest

/// About Treewise in the UI review (ADR 0103): AppKit's panel with Treewise's credits.
extension UIReviewTests {
    @MainActor
    func reviewAbout(in app: XCUIApplication, appearance: String?) {
        app.menuBarItems["Treewise"].menuItems["About Treewise"].click()
        // AppKit's About panel is a dialog to XCUITest, not a window.
        let credits = NSPredicate(format: "value CONTAINS 'Windows Explorer'")
        let about = app.dialogs.containing(credits).firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: Self.timeout), "About opens")
        settleScreen()
        review(about, as: "about", appearance: appearance)
        about.typeKey("w", modifierFlags: .command)
    }
}
