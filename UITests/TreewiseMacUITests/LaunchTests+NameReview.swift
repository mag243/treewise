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

    /// Approves the one proposed name in the overview, renames and closes it.
    @MainActor
    private func renameInOverview(in app: XCUIApplication) {
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.waitForExistence(timeout: Self.launchTimeout), "the overview opens")
        // The odd photo has only the date of the file, which Approve All leaves to check.
        let approve = review.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Approve 1 with Dates to Check'")
        ).firstMatch
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
