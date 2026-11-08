import XCTest

/// How the overview lays out its rows.
extension LaunchTests {
    /// Wider than the overview's list, in capitals, as a query takes at most 128 characters.
    private static let longName =
        "A LONG NAME ABOUT THE WALK ALONG THE BEACH TO THE OLD lighthouse at sunset with friends "
        + "AND THE WAY BACK THROUGH THE DUNES.heic"
    /// More than this is more than one line of the proposed name.
    private static let oneLine: CGFloat = 24
    /// The least room the overview opens with, so a good number of names fit in it.
    private static let openingSize = CGSize(width: 980, height: 620)

    @MainActor
    func testTheOverviewOpensWithRoomForItsNames() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        XCTAssertGreaterThanOrEqual(review.frame.width, Self.openingSize.width, "its width")
        XCTAssertGreaterThanOrEqual(review.frame.height, Self.openingSize.height, "its height")
    }

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
