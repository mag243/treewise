import XCTest

/// The menu beside an add-on's pattern lists the patterns found in the folder (ADR 0067).
extension LaunchTests {
    @MainActor
    func testThePatternMenuListsWhatTheAddOnFoundWithHowManyNamesFit() throws {
        // A fourth name that fits: four of the five names fit the pattern the add-on finds.
        let folder = try makeHolidayFolder()
        try writePhoto(to: folder.appendingPathComponent("2026.08.17 Holiday - Pier.heic"))
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        let header = review.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add-ons'"))
            .firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: Self.launchTimeout), "the header shows")
        if header.label.hasPrefix("Add-ons:") { header.click() }
        let menu = review.buttons.matching(
            NSPredicate(format: "label IN {'Saved Patterns', 'Choose a Saved Pattern'}")
        ).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: Self.launchTimeout), "the menu shows")
        menu.click()
        XCTAssertTrue(
            app.menuItems["Found in This Folder"].waitForExistence(timeout: Self.launchTimeout),
            "the found patterns come first")
        let found = app.menuItems.matching(NSPredicate(format: "title ENDSWITH ' names'"))
            .firstMatch
        XCTAssertTrue(found.exists, "a found pattern says how many names fit it")
        app.typeKey(.escape, modifierFlags: [])
    }
}
