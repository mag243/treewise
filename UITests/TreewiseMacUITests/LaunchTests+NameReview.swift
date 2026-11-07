import ImageIO
import UniformTypeIdentifiers
import XCTest

/// Renaming from the overview of proposed names (ADR 0057).
extension LaunchTests {
    /// Names that follow one pattern, so the free module proposes a name for the odd one.
    private static let patternNames = [
        "2026.08.14 Holiday - Beach.heic", "2026.08.15 Holiday - Dunes.heic",
        "2026.08.16 Holiday - Harbour.heic",
    ]
    private static let oddName = "Lighthouse.heic"
    /// The side of the photos, in pixels.
    private static let photoSide = 64

    /// A folder `Holiday` in the root with three photos whose names follow a pattern and one
    /// whose name does not. Real HEIC images, as Quick Look previews photos differently.
    private func makeHolidayFolder() throws -> URL {
        let folder = try XCTUnwrap(root).appendingPathComponent("Holiday", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in Self.patternNames + [Self.oddName] {
            try writePhoto(to: folder.appendingPathComponent(name))
        }
        return folder
    }

    private func writePhoto(to url: URL) throws {
        let side = Self.photoSide
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL, UTType.heic.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "the photo is written")
    }

    @MainActor
    func testRenamingTheFileInThePreviewKeepsTreewiseRunning() throws {
        let folder = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.waitForExistence(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let odd = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(odd.waitForExistence(timeout: Self.launchTimeout), "Holiday opens")
        odd.click()
        showDetails(in: app)

        odd.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()
        renameInOverview(in: app)

        XCTAssertTrue(
            app.eventually {
                !FileManager.default.fileExists(
                    atPath: folder.appendingPathComponent(Self.oddName).path)
            }, "the odd photo has a new name")
        // The details pane previewed the file that was renamed; choosing files again
        // hands that preview new items.
        let renamed = app.tables.staticTexts.matching(
            NSPredicate(format: "value ENDSWITH 'Lighthouse.heic' AND value != 'Lighthouse.heic'")
        ).firstMatch
        XCTAssertTrue(renamed.waitForExistence(timeout: Self.launchTimeout), "the list shows it")
        renamed.click()
        app.tables.staticTexts[Self.patternNames[0]].click()
        renamed.click()
        XCTAssertTrue(
            app.tables.firstMatch.waitForExistence(timeout: Self.launchTimeout),
            "the browser window is still there")
        XCTAssertEqual(app.state, .runningForeground, "and Treewise keeps running")
    }

    @MainActor
    func testArrowKeysStepThroughThePartsOfAChoice() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.waitForExistence(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let odd = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(odd.waitForExistence(timeout: Self.launchTimeout), "Holiday opens")
        odd.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: Self.launchTimeout), "the overview opens")
        usePattern("Trip - <Sea|Land>", in: review)

        let name = review.textFields.matching(NSPredicate(format: "value BEGINSWITH 'Trip - '"))
            .firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: Self.launchTimeout), "a name is proposed")
        // A double click on the row edits its name.
        review.outlines.staticTexts[Self.oddName].doubleClick()
        XCTAssertTrue(
            app.eventually { (name.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "the name is edited")
        let first = name.value as? String
        name.typeKey(.downArrow, modifierFlags: [])
        let second = name.value as? String
        XCTAssertNotEqual(first, second, "↓ goes to the other part")
        XCTAssertEqual(Set([first, second]), ["Trip - Sea.heic", "Trip - Land.heic"])
        name.typeKey(.downArrow, modifierFlags: [])
        XCTAssertEqual(name.value as? String, first, "and from the last back to the first")

        name.typeKey(.end, modifierFlags: [])
        name.typeText("x")
        let typed = name.value as? String
        name.typeKey(.upArrow, modifierFlags: [])
        XCTAssertEqual(name.value as? String, typed, "once typed, ↑ leaves the text alone")
    }

    @MainActor
    func testRenameWithSuggestionsPutsAProposalInTheName() throws {
        let folder = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.waitForExistence(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let odd = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(odd.waitForExistence(timeout: Self.launchTimeout), "Holiday opens")
        odd.rightClick()
        app.tables.menus.menuItems["Rename with Suggestions"].click()

        // The free module proposes the folder's pattern, which keeps the photo's own word.
        let option = app.buttons.matching(
            NSPredicate(format: "label ENDSWITH 'Lighthouse.heic' AND label != 'Lighthouse.heic'")
        ).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: Self.launchTimeout), "a name is proposed")
        let proposed = option.label
        XCTAssertTrue(app.buttons["Suggest Names…"].exists, "the overview is a click away")
        option.click()

        let field = app.tables.textFields.firstMatch
        XCTAssertEqual(field.value as? String, proposed, "the option is in the name")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: folder.appendingPathComponent(Self.oddName).path),
            "and nothing is renamed before Return")
        field.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.eventually {
                FileManager.default.fileExists(atPath: folder.appendingPathComponent(proposed).path)
            }, "Return renames it")
    }

    @MainActor
    func testOptionEscapeOffersProposalsToChooseWithTheKeyboard() throws {
        let folder = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.waitForExistence(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let odd = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(odd.waitForExistence(timeout: Self.launchTimeout), "Holiday opens")
        odd.click()
        app.menuBarItems["File"].menuItems["Rename"].click()
        let field = app.tables.textFields.firstMatch
        XCTAssertTrue(
            app.eventually { (field.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "the name is edited")

        app.typeKey(.escape, modifierFlags: .option)
        let option = app.buttons.matching(
            NSPredicate(format: "label ENDSWITH 'Lighthouse.heic' AND label != 'Lighthouse.heic'")
        ).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: Self.launchTimeout), "a name is proposed")
        let proposed = option.label
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(field.value as? String, proposed, "Return takes the highlighted option")
        XCTAssertFalse(option.exists, "and closes the list")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: folder.appendingPathComponent(Self.oddName).path),
            "but renames nothing yet")
    }

    @MainActor
    func testASavedPatternIsPickedFromTheAddOnsHeader() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.waitForExistence(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let odd = app.tables.staticTexts[Self.oddName]
        XCTAssertTrue(odd.waitForExistence(timeout: Self.launchTimeout), "Holiday opens")
        odd.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: Self.launchTimeout), "the overview opens")
        let header = review.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add-ons'"))
            .firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: Self.launchTimeout), "the header shows")
        if header.label.hasPrefix("Add-ons:") { header.click() }

        let menu = review.buttons.matching(
            NSPredicate(format: "label IN {'Saved Patterns', 'Choose a Saved Pattern'}")
        ).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: Self.launchTimeout), "the menu shows")
        menu.click()
        let example = app.menuItems.matching(
            NSPredicate(format: "title BEGINSWITH 'Folder and Number'")
        ).firstMatch
        XCTAssertTrue(
            example.waitForExistence(timeout: Self.launchTimeout), "it lists the examples")
        example.click()
        let name = review.descendants(matching: .any).matching(
            NSPredicate(format: "value == 'Holiday 1.heic' OR label == 'Holiday 1.heic'")
        ).firstMatch
        XCTAssertTrue(
            name.waitForExistence(timeout: Self.launchTimeout), "the folder takes the pattern")
    }

    @MainActor
    func testThePatternMenuListsWhatTheAddOnFoundWithHowManyNamesFit() throws {
        _ = try makeHolidayFolder()
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

    @MainActor
    func testSpaceShowsTheFileOfARowInQuickLook() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        review.outlines.staticTexts[Self.oddName].click()
        let windows = app.windows.count
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(
            app.eventually { app.windows.count == windows + 1 }, "the Quick Look panel opens")
    }

    @MainActor
    func testReturnEditsTheNameOfTheSelectedRow() throws {
        _ = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        review.outlines.staticTexts[Self.oddName].click()
        app.typeKey(.return, modifierFlags: [])
        let name = review.outlines.textFields.firstMatch
        XCTAssertTrue(
            app.eventually { (name.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "the name is edited")
    }

    /// Opens Holiday, and the overview for one of its files.
    @MainActor
    private func openReview(of file: String, in app: XCUIApplication) throws -> XCUIElement {
        let holiday = app.tables.staticTexts["Holiday"]
        XCTAssertTrue(holiday.waitForExistence(timeout: Self.launchTimeout))
        holiday.doubleClick()
        let row = app.tables.staticTexts[file]
        XCTAssertTrue(row.waitForExistence(timeout: Self.launchTimeout), "Holiday opens")
        row.rightClick()
        app.tables.menus.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: Self.launchTimeout), "the overview opens")
        let shown = review.outlines.staticTexts[file]
        XCTAssertTrue(shown.waitForExistence(timeout: Self.launchTimeout), "it lists the file")
        return review
    }

    /// Changes the free module's pattern in the overview's add-ons header.
    @MainActor
    private func usePattern(_ pattern: String, in review: XCUIElement) {
        // The header closes to one line, `Add-ons: …`, once the folder has its add-ons.
        let header = review.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add-ons'"))
            .firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: Self.launchTimeout), "the header shows")
        if header.label.hasPrefix("Add-ons:") { header.click() }
        let change = review.links["Change"].firstMatch
        XCTAssertTrue(change.waitForExistence(timeout: Self.launchTimeout), "the pattern shows")
        change.click()
        let field = review.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.launchTimeout), "it can be changed")
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(pattern)
        review.buttons["Done"].firstMatch.click()
    }

    /// Approves the one proposed name in the overview, renames and closes it.
    @MainActor
    private func renameInOverview(in app: XCUIApplication) {
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: Self.launchTimeout), "the overview opens")
        // The odd photo has only the date of the file, which Approve All takes too (ADR 0058).
        let approve = review.buttons["Approve All"]
        XCTAssertTrue(approve.waitForExistence(timeout: Self.launchTimeout), "a name is proposed")
        approve.click()
        let rename = review.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rename 1'"))
            .firstMatch
        XCTAssertTrue(app.eventually { rename.exists && rename.isEnabled }, "the name is approved")
        rename.click()
        let done = review.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: Self.launchTimeout), "the files are renamed")
        done.click()
    }

    /// Opens the details pane, with its preview of the selection, unless it is open.
    @MainActor
    private func showDetails(in app: XCUIApplication) {
        let view = app.menuBarItems["View"]
        view.click()
        let show = view.menuItems["Show Details"]
        if show.waitForExistence(timeout: Self.launchTimeout) {
            show.click()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}
