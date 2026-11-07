import XCTest

/// How the overview lays out its rows.
extension LaunchTests {
    private static let longName =
        "A long name about the walk along the beach to the old lighthouse at sunset with friends.heic"
    /// More than this is more than one line of the proposed name.
    private static let oneLine: CGFloat = 24

    @MainActor
    func testALongProposedNameGoesOnToANextLine() throws {
        let folder = try makeHolidayFolder()
        try writePhoto(to: folder.appendingPathComponent(Self.longName))
        let app = try launchApp()
        let review = try openReview(of: Self.longName, in: app)
        review.outlines.staticTexts[Self.longName].click()
        let field = review.textFields.matching(
            NSPredicate(format: "value CONTAINS 'lighthouse at sunset with friends'")
        ).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.launchTimeout), "the name is proposed")
        XCTAssertTrue(
            app.eventually { field.frame.height > Self.oneLine },
            "the whole name shows, on more than one line")
    }
}
