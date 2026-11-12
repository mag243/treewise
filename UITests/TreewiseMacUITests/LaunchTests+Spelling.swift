import XCTest

/// The spelling of a name is checked on request, with the standard Spelling and Grammar
/// menu (ADR 0084). Whether Check Spelling While Typing starts off is a test of
/// `BrowserSettings`: XCUITest does not show a menu item's checkmark.
extension LaunchTests {
    @MainActor
    func testTheEditMenuOffersSpellingAndGrammarWithoutCorrecting() throws {
        let app = try launchApp()
        XCTAssertTrue(app.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))
        let spelling = app.menuBars.menuBarItems["Edit"].menuItems["Spelling and Grammar"]
        app.menuBars.menuBarItems["Edit"].click()
        XCTAssertTrue(spelling.exists, "Edit has Spelling and Grammar")
        spelling.hover()
        XCTAssertTrue(spelling.menuItems["Show Spelling and Grammar"].exists)
        XCTAssertTrue(spelling.menuItems["Check Document Now"].exists)
        XCTAssertFalse(
            spelling.menuItems["Correct Spelling Automatically"].exists,
            "a name is never corrected without the user")
        XCTAssertTrue(
            spelling.menuItems["Check Spelling While Typing"].isEnabled,
            "checking while typing can be turned on in every window")
        app.typeKey(.escape, modifierFlags: [])
        app.typeKey(.escape, modifierFlags: [])
    }
}
