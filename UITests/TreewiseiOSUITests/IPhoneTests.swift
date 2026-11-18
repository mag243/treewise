import XCTest

/// The iPhone's layout, modelled on Files (ADR 0132): the locations as a screen of their
/// own, a folder's enclosing folder to go up to, one menu, and while selecting a bar below.
/// Run on the pinned iPhone by `tools/build.sh iosuitest --iphone`; the iPads' runs skip it.
final class IPhoneTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    /// Starts in a state of its own, at the first location, Documents.
    @MainActor
    private func openDocuments() -> XCUIApplication {
        let app = launch(state: UUID().uuidString)
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testTheStartNamesTheIPhonesOwnFiles() {
        let app = launch(state: UUID().uuidString, fixture: false)
        let hint = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'On My iPhone'")
        ).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: Self.timeout), "not On My iPad")
    }

    /// A Pro Max's landscape width is regular, but its height is compact.
    @MainActor
    func testLandscapeKeepsTheIPhonesLayout() {
        let app = openDocuments()

        XCUIDevice.shared.orientation = .landscapeLeft

        let more = app.buttons["moreMenu"].firstMatch
        XCTAssertTrue(app.eventually { more.exists }, "the one menu, not the iPad's toolbar")
        XCTAssertFalse(sidebar(of: app).staticTexts["Work"].isHittable, "no sidebar beside it")
    }

    @MainActor
    func testBackFromALocationShowsTheLocationsAndAnotherOneOpens() {
        let app = openDocuments()

        app.navigationBars["Documents"].buttons.firstMatch.tap()

        let work = sidebar(of: app).staticTexts["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: Self.timeout), "the locations' screen")
        work.tap()
        XCTAssertTrue(row("Report.txt", in: app).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testAFolderGoesUpToTheEnclosingFolderNamedOnItsButton() {
        let app = openDocuments()
        row("Projects", in: app).tap()
        let up = app.buttons["enclosingFolder"].firstMatch
        XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(up.label, "Documents")

        up.tap()

        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(app.buttons["enclosingFolder"].exists, "a location's top has none")
    }

    @MainActor
    func testTheMenuStartsSelectingAndTheBarBelowActsOnTheSelection() {
        let app = openDocuments()
        app.buttons["moreMenu"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()
        let copy = app.toolbars.buttons["Copy"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: Self.timeout), "the bar below")
        XCTAssertFalse(copy.isEnabled, "nothing selected yet")
        XCTAssertFalse(
            app.navigationBars.buttons["Treewise"].exists,
            "Select All takes the back button's place")

        row("Notes.md", in: app).tap()
        XCTAssertTrue(app.eventually { copy.isEnabled })
        copy.tap()
        app.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.eventually { !copy.exists }, "selecting ended")
        app.buttons["moreMenu"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Paste"].firstMatch.isEnabled, "the copy can be pasted")
    }

    @MainActor
    func testMoveToMovesTheSelectionIntoTheFolderBrowsedTo() {
        let app = openDocuments()
        app.buttons["moreMenu"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()
        row("Notes.md", in: app).tap()
        app.toolbars.buttons["Actions"].firstMatch.tap()
        app.buttons["Move to…"].firstMatch.tap()
        let sheet = app.navigationBars["Move to Folder"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(app.buttons["moveToConfirm"].firstMatch.isEnabled, "no folder yet")

        app.buttons["Work"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Work"].waitForExistence(timeout: Self.timeout))
        app.buttons["moveToConfirm"].firstMatch.tap()

        let notes = row("Notes.md", in: app)
        XCTAssertTrue(app.eventually { !notes.exists }, "moved away")
        app.buttons["Done"].firstMatch.tap()
        app.navigationBars["Documents"].buttons.firstMatch.tap()
        sidebar(of: app).staticTexts["Work"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testThePasteBarPastesTheCopyAndItsButtonEmptiesTheClipboard() {
        let app = openDocuments()
        selectAndPerform("Copy", on: "Notes.md", in: app)
        app.buttons["Done"].firstMatch.tap()
        let paste = app.toolbars.buttons["pasteBar"].firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: Self.timeout), "the bar below")
        XCTAssertEqual(paste.label, "Paste “Notes.md”")

        app.navigationBars["Documents"].buttons.firstMatch.tap()
        sidebar(of: app).staticTexts["Work"].tap()
        XCTAssertTrue(row("Report.txt", in: app).waitForExistence(timeout: Self.timeout))
        app.toolbars.buttons["pasteBar"].firstMatch.tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

        XCTAssertTrue(paste.exists, "a copy stays for more pastes")
        app.toolbars.buttons["emptyClipboard"].firstMatch.tap()
        XCTAssertTrue(app.eventually { !paste.exists }, "the clipboard emptied")
    }

    @MainActor
    func testMoveToOffersTheFolderShownBefore() {
        let app = openDocuments()
        row("Projects", in: app).tap()
        let up = app.buttons["enclosingFolder"].firstMatch
        XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
        up.tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        selectAndPerform("Actions", on: "Notes.md", in: app)
        app.buttons["Move to…"].firstMatch.tap()

        let recent = app.buttons["recent-Projects"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: Self.timeout), "Projects among Recent")
        recent.tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: Self.timeout))
        app.buttons["moveToConfirm"].firstMatch.tap()

        let notes = row("Notes.md", in: app)
        XCTAssertTrue(app.eventually { !notes.exists }, "moved away")
    }

    @MainActor
    func testShareOffersTheSelectionToTheSystemsShareSheet() {
        let app = openDocuments()
        selectAndPerform("Actions", on: "Notes.md", in: app)
        let share = app.buttons["Share…"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: Self.timeout), "Share… in Actions")

        share.tap()

        XCTAssertTrue(
            app.otherElements["ActivityListView"].waitForExistence(timeout: Self.timeout),
            "the share sheet")
    }

    /// Selects a row through the folder's menu and taps a button of the bar below.
    @MainActor
    private func selectAndPerform(_ button: String, on name: String, in app: XCUIApplication) {
        app.buttons["moreMenu"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()
        row(name, in: app).tap()
        let item = app.toolbars.buttons[button].firstMatch
        XCTAssertTrue(app.eventually { item.isEnabled }, "\(button) below")
        item.tap()
    }
}
