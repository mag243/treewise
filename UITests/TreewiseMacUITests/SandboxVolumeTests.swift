import XCTest

/// The overview of proposed names from start to end on the sandbox volumes (PLAN.md M7,
/// acceptance). Run with `tools/build.sh sandboxtest`, which makes the volumes afresh and
/// passes them in `TREEWISE_SANDBOX`; `ci` skips this class.
final class SandboxVolumeTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    private static let folder = "Taxes"
    private static let misspelled = "2026.02.23 Tax Ofice - Payroll 2026.01.pdf"
    private static let late = "2026-03-20 Late filing notice.pdf"
    private static let reminder = "Payment reminder.pdf"
    private static let scan = "scan0042.pdf"
    private static let typed = "2026.03.01 Tax Office - Typed by hand.pdf"
    /// Where the Skip menu is, from the right end of its row.
    private static let skipFromTheRowsEnd: CGFloat = -34

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheOverviewStepsEditsApprovesSkipsAppliesAndUndoes() throws {
        let app = try launch()
        app.go(to: "Documents/Taxes", timeout: Self.timeout)
        // The list shows what is on the volume; the test runner itself stays off the volume,
        // where macOS may ask it for access.
        let list = app.windows(titled: Self.folder).firstMatch.tables.firstMatch
        XCTAssertTrue(list.staticTexts[Self.reminder].waitForExistence(timeout: Self.timeout))
        let review = openOverview(in: app)

        stepToTheScanAndTypeItsName(in: review, app: app)
        checkbox(of: Self.scan, in: review).click()
        let corrected = try approveTheMisspelledName(in: review, app: app)
        skipTheLateNotice(in: review, app: app)

        review.buttons["Rename 2 Items"].click()
        let undo = review.buttons["Undo Rename"]
        XCTAssertTrue(undo.appeared(timeout: Self.timeout), "the result shows")
        assert(present: [Self.typed, corrected, Self.late, Self.reminder], in: list, app: app)
        assert(absent: [Self.scan, Self.misspelled], in: list, app: app)

        undo.click()
        assert(present: [Self.scan, Self.misspelled, Self.late, Self.reminder], in: list, app: app)
        assert(absent: [Self.typed, corrected], in: list, app: app)
    }

    // MARK: - Steps

    /// The name field shows only in the selected row, so it shows where the selection is.
    @MainActor
    private func stepToTheScanAndTypeItsName(in review: XCUIElement, app: XCUIApplication) {
        review.outlines.staticTexts[Self.reminder].click()
        let field = row(of: Self.scan, in: review).textFields.firstMatch
        let earlier = row(of: Self.reminder, in: review).textFields.firstMatch
        XCTAssertTrue(earlier.appeared(timeout: Self.timeout), "the clicked row is selected")
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(field.appeared(timeout: Self.timeout), "the arrow key goes to the next")
        XCTAssertTrue(earlier.disappeared(timeout: Self.timeout), "and leaves the row before")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.eventually { (field.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "Return edits the name")
        field.typeKey("a", modifierFlags: .command)
        field.typeText(Self.typed)
        field.typeKey(.return, modifierFlags: [])
    }

    /// Approves the proposal for the misspelled name, and returns that proposal.
    @MainActor
    private func approveTheMisspelledName(
        in review: XCUIElement, app: XCUIApplication
    ) throws -> String {
        review.outlines.staticTexts[Self.misspelled].click()
        let field = row(of: Self.misspelled, in: review).textFields.firstMatch
        XCTAssertTrue(field.appeared(timeout: Self.timeout), "the row is selected")
        XCTAssertTrue(
            app.eventually {
                (field.value as? String)?.contains("Tax Office") == true
            }, "the proposal corrects the name")
        let corrected = try XCTUnwrap(field.value as? String)
        checkbox(of: Self.misspelled, in: review).click()
        return corrected
    }

    @MainActor
    private func skipTheLateNotice(in review: XCUIElement, app: XCUIApplication) {
        // Only the selected row offers Skip.
        review.outlines.staticTexts[Self.late].click()
        let row = row(of: Self.late, in: review)
        let skip = row.menuButtons["Skip"]
        XCTAssertTrue(skip.appeared(timeout: Self.timeout), "the selected row offers Skip")
        // SwiftUI reports this menu's frame off the row, so XCUITest cannot click the element.
        row.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: Self.skipFromTheRowsEnd, dy: 0)).click()
        app.menuItems["Skip"].firstMatch.click()
        XCTAssertTrue(row.links["Undo Skip"].appeared(timeout: Self.timeout), "it is skipped")
    }

    // MARK: - Helpers

    @MainActor
    private func launch() throws -> XCUIApplication {
        guard let sandbox = ProcessInfo.processInfo.environment["TREEWISE_SANDBOX"] else {
            throw XCTSkip("Run with tools/build.sh sandboxtest, which attaches the sandbox.")
        }
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseSandbox", sandbox, "-TreewiseFreshSettings", "YES",
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.tables.firstMatch.appeared(timeout: Self.timeout))
        return app
    }

    /// With nothing selected, the overview reviews the whole folder.
    @MainActor
    private func openOverview(in app: XCUIApplication) -> XCUIElement {
        let file = app.menuBarItems["File"]
        file.click()
        file.menuItems["Suggest Names…"].click()
        let review = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Suggest Names'"))
            .firstMatch
        XCTAssertTrue(review.appeared(timeout: Self.timeout), "the overview opens")
        XCTAssertTrue(
            checkbox(of: Self.scan, in: review).appeared(timeout: Self.timeout),
            "it lists the files to rename")
        return review
    }

    @MainActor
    private func row(of name: String, in review: XCUIElement) -> XCUIElement {
        review.outlines.outlineRows.containing(.staticText, identifier: name).firstMatch
    }

    @MainActor
    private func checkbox(of name: String, in review: XCUIElement) -> XCUIElement {
        row(of: name, in: review).checkBoxes.firstMatch
    }

    @MainActor
    private func assert(present names: [String], in list: XCUIElement, app: XCUIApplication) {
        for name in names {
            XCTAssertTrue(list.staticTexts[name].appeared(timeout: Self.timeout), "\(name) shows")
        }
    }

    @MainActor
    private func assert(absent names: [String], in list: XCUIElement, app: XCUIApplication) {
        for name in names {
            XCTAssertTrue(
                list.staticTexts[name].disappeared(timeout: Self.timeout), "\(name) is gone")
        }
    }
}
