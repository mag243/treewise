import XCTest

/// About Treewise and Help > Acknowledgements.
extension LaunchTests {
    @MainActor
    func testAboutSaysWhatTreewiseIsAndWhereItsLicencesAre() throws {
        let app = try launchApp()
        XCTAssertTrue(app.windows.firstMatch.appeared(timeout: Self.launchTimeout))
        app.menuBarItems["Treewise"].menuItems["About Treewise"].click()
        let credits = app.textViews.matching(
            NSPredicate(format: "value CONTAINS 'Windows Explorer'")
        ).firstMatch
        XCTAssertTrue(credits.appeared(timeout: Self.launchTimeout), "About says what it is")
        XCTAssertTrue(
            (credits.value as? String)?.contains("Mozilla\u{00A0}Public\u{00A0}License") == true,
            "and under which licence")
    }

    @MainActor
    func testAcknowledgementsHoldSparklesLicence() throws {
        let app = try launchApp()
        XCTAssertTrue(app.windows.firstMatch.appeared(timeout: Self.launchTimeout))
        app.menuBarItems["Help"].menuItems["Acknowledgements"].click()
        let text = app.windows["Acknowledgements"].textViews["acknowledgements"]
        XCTAssertTrue(text.appeared(timeout: Self.launchTimeout), "the window opens")
        let licence = text.value as? String ?? ""
        XCTAssertTrue(licence.contains("Sparkle"), "it names Sparkle")
        XCTAssertTrue(licence.contains("Permission is hereby granted"), "with its licence")
    }
}
