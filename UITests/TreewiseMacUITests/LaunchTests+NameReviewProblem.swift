import XCTest

/// The bar above the overview's list that says what kept it from proposing names.
extension LaunchTests {
    /// A folder Treewise cannot read opens an overview that says so, not an empty list
    /// without a word.
    @MainActor
    func testTheOverviewSaysWhenTheFolderCannotBeRead() throws {
        let folder = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.appeared(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let odd = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(odd.appeared(timeout: Self.launchTimeout), "Holiday opens")
        odd.click()
        // Unreadable from here on; readable again so the test's folder can be removed.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.path)
        addTeardownBlock {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: folder.path)
        }

        odd.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()

        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.appeared(timeout: Self.launchTimeout), "the overview opens")
        let problem = review.staticTexts["reviewProblem"]
        XCTAssertTrue(problem.appeared(timeout: Self.launchTimeout), "it says what went wrong")
        XCTAssertTrue(
            (problem.value as? String)?.contains("could not be read") == true,
            "that the folder could not be read")
        XCTAssertTrue(review.buttons["Try Again"].exists, "and offers to try again")
    }
}
