import XCTest

/// How the overview lays out its rows.
extension LaunchTests {
    /// Wider than the overview's list, in capitals, as a query takes at most 128 characters.
    private static let longName =
        "A LONG NAME ABOUT THE WALK ALONG THE BEACH TO THE OLD lighthouse at sunset with friends "
        + "AND THE WAY BACK THROUGH THE DUNES.heic"
    /// More than this is more than one line of the proposed name.
    private static let oneLine: CGFloat = 24
    /// How far the last part of a row may end before the row's own end.
    private static let rowEndTolerance: CGFloat = 12
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

    /// The room around the buttons at the foot of the overview, as Apple's guidelines ask
    /// of a window's content.
    private static let footMargin: CGFloat = 20
    /// How far a measured edge may be off, for rounding to points.
    private static let marginTolerance: CGFloat = 1

    @MainActor
    func testTheButtonsAtTheFootHaveRoomAroundThem() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        let window = review.frame
        for title in ["Cancel", "Show Preview"] {
            let button = review.buttons[title]
            XCTAssertTrue(button.appeared(timeout: Self.launchTimeout), "\(title) shows")
            XCTAssertGreaterThanOrEqual(
                window.maxY - button.frame.maxY, Self.footMargin - Self.marginTolerance,
                "room below \(title): \(button.frame) in \(window)")
        }
        let rename = review.buttons.matching(NSPredicate(format: "title BEGINSWITH 'Rename'"))
            .firstMatch
        XCTAssertGreaterThanOrEqual(
            window.maxX - rename.frame.maxX, Self.footMargin - Self.marginTolerance,
            "room right of Rename: \(rename.frame) in \(window)")
    }

    @MainActor
    func testANameThatAlreadyFitsShowsOnce() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.appeared(timeout: Self.launchTimeout), "the folder shows")
        holiday.doubleClick()
        XCTAssertTrue(
            app.tables.staticTexts[Self.oddName].appeared(timeout: Self.launchTimeout),
            "Holiday opens")
        // Nothing selected, so the whole folder is reviewed.
        let file = app.menuBarItems["File"]
        file.click()
        file.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.appeared(timeout: Self.launchTimeout), "the overview opens")
        let alreadyFit = review.buttons.matching(
            NSPredicate(format: "label ENDSWITH 'files already fit'")
        ).firstMatch
        XCTAssertTrue(alreadyFit.appeared(timeout: Self.launchTimeout), "it shows them")
        alreadyFit.click()
        let name = "2026.08.14 Holiday - Beach.heic"
        let shown = review.outlines.staticTexts.matching(
            NSPredicate(format: "value == %@ OR label == %@", name, name))
        XCTAssertTrue(shown.firstMatch.appeared(timeout: Self.launchTimeout), "it lists it")
        XCTAssertEqual(shown.count, 1, "nothing changes, so the name shows once")
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
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "the name is proposed")
        XCTAssertTrue(
            app.eventually { field.frame.height > Self.oneLine },
            "the whole name shows, on more than one line")
    }

    @MainActor
    func testARowThatIsNotSelectedUsesTheListsWidth() throws {
        // A second file whose name does not follow the folder's pattern, for a row beside
        // the one selected.
        try writePhoto(to: try makeHolidayFolder().appendingPathComponent("Sunset.heic"))
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.appeared(timeout: Self.launchTimeout), "the folder shows")
        holiday.doubleClick()
        XCTAssertTrue(
            app.tables.staticTexts[Self.oddName].appeared(timeout: Self.launchTimeout),
            "Holiday opens")
        // Nothing selected, so the whole folder is reviewed.
        let file = app.menuBarItems["File"]
        file.click()
        file.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.appeared(timeout: Self.launchTimeout), "the overview opens")
        let odd = review.outlines.staticTexts[Self.oddName]
        XCTAssertTrue(odd.appeared(timeout: Self.launchTimeout), "it lists the files")
        odd.click()
        let other = review.outlines.cells.matching(NSPredicate(format: "selected == NO"))
            .containing(NSPredicate(format: "label == 'Approve'")).firstMatch
        XCTAssertTrue(other.appeared(timeout: Self.launchTimeout), "another row shows")
        // The names take the row's width, so what follows them ends at the row's end.
        let last = try XCTUnwrap(
            other.children(matching: .any).allElementsBoundByIndex.last, "the row shows a file")
        XCTAssertEqual(
            last.frame.maxX, other.frame.maxX, accuracy: Self.rowEndTolerance,
            "the row's end follows its names at the list's width: \(last.frame) in \(other.frame)")
    }
}
