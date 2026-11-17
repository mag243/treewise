import XCTest

/// The iPad app's locations and browsing on the simulator (ADR 0045, 0111, 0114): each test
/// runs in a state of its own, with the fixture's folders `Documents` and `Work` added.
final class LocationsTests: XCTestCase {
    static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        // The sidebar stays beside the folder in landscape.
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testTheStartSaysOneTopFolderIsEnough() {
        let app = launch(state: UUID().uuidString, fixture: false)
        let hint = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'everything below it comes along'")
        ).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: Self.timeout), "the start says it")
        XCTAssertTrue(app.buttons["Add Location"].firstMatch.exists)
    }

    @MainActor
    func testAddLocationOpensThePicker() {
        let app = launch(state: UUID().uuidString, fixture: false)
        let add = app.buttons["Add Location"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: Self.timeout))
        add.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: Self.timeout), "the picker opens")
        cancel.tap()
        XCTAssertTrue(add.waitForExistence(timeout: Self.timeout), "and closes again")
    }

    @MainActor
    func testTheAddedFoldersShowInTheSidebarAndTheirFilesInTheList() {
        let app = launch(state: UUID().uuidString)
        let sidebar = sidebar(of: app)
        XCTAssertTrue(sidebar.staticTexts["Documents"].waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(sidebar.staticTexts["Work"].exists)
        sidebar.staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(row("Projects", in: app).exists, "with its folder")
    }

    @MainActor
    func testSortingByNameDescendingPutsTheLastNameFirst() throws {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        let budget = row("Budget.txt", in: app)
        let notes = row("Notes.md", in: app)
        XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))
        XCTAssertLessThan(budget.frame.minY, notes.frame.minY, "by name, ascending")
        // The Name column's heading, as on the Mac, turns the order round.
        app.buttons["Name"].firstMatch.tap()
        XCTAssertTrue(
            app.eventually { notes.frame.minY < budget.frame.minY }, "by name, descending")
    }

    @MainActor
    func testAChevronInThePathOpensAFolderNextToTheOneShown() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        let projects = row("Projects", in: app)
        XCTAssertTrue(projects.waitForExistence(timeout: Self.timeout))
        projects.tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: Self.timeout))

        app.buttons["subfolders"].firstMatch.tap()
        let archive = app.buttons["Archive"].firstMatch
        XCTAssertTrue(archive.waitForExistence(timeout: Self.timeout), "the folders in Documents")
        archive.tap()

        XCTAssertTrue(app.navigationBars["Archive"].waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testOpeningAFileShowsItInQuickLook() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Work"].tap()
        let report = row("Report.txt", in: app)
        XCTAssertTrue(report.waitForExistence(timeout: Self.timeout))
        report.tap()
        XCTAssertTrue(
            app.otherElements["QLPreviewControllerView"].waitForExistence(timeout: Self.timeout),
            "Quick Look shows the file")
    }

    @MainActor
    func testARelaunchKeepsTheLocationsAndTheFolderShown() {
        let state = UUID().uuidString
        let app = launch(state: state)
        sidebar(of: app).staticTexts["Documents"].tap()
        let projects = row("Projects", in: app)
        XCTAssertTrue(projects.waitForExistence(timeout: Self.timeout))
        projects.tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: Self.timeout))
        // To the background first, so the app keeps where it was, as when the user leaves.
        XCUIDevice.shared.press(.home)
        app.terminate()

        let again = launch(state: state)
        XCTAssertTrue(
            again.navigationBars["Projects"].waitForExistence(timeout: Self.timeout),
            "the folder shown comes back")
        XCTAssertTrue(sidebar(of: again).staticTexts["Documents"].exists)
        XCTAssertTrue(sidebar(of: again).staticTexts["Work"].exists)
    }

    @MainActor
    func testAFolderOutOfReachStaysGreyedWithReconnectAndCanBeRemoved() {
        let state = UUID().uuidString
        let app = launch(state: state)
        XCTAssertTrue(sidebar(of: app).staticTexts["Work"].waitForExistence(timeout: Self.timeout))
        app.terminate()

        let again = launch(state: state, removing: "Work")
        let work = sidebar(of: again).buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: Self.timeout), "it stays, by its name")
        work.press(forDuration: 1)
        XCTAssertTrue(again.buttons["Reconnect…"].waitForExistence(timeout: Self.timeout))
        again.buttons["Remove Location"].tap()
        XCTAssertTrue(work.waitForNonExistence(timeout: Self.timeout), "and leaves when removed")
    }

    /// A location goes by the name the user gives it, after a relaunch too, while its
    /// folder keeps its own; an empty name gives the folder's name back (ADR 0119).
    @MainActor
    func testARenamedLocationKeepsItsNameAndAnEmptyNameGivesTheFolderBack() {
        let state = UUID().uuidString
        let app = launch(state: state)
        rename(sidebar(of: app).staticTexts["Work"], to: "Office", in: app)
        XCTAssertTrue(
            sidebar(of: app).staticTexts["Office"].waitForExistence(timeout: Self.timeout))
        XCUIDevice.shared.press(.home)
        app.terminate()

        let again = launch(state: state)
        let office = sidebar(of: again).staticTexts["Office"]
        XCTAssertTrue(office.waitForExistence(timeout: Self.timeout), "the name stays")
        rename(office, to: "", in: again)
        XCTAssertTrue(
            sidebar(of: again).staticTexts["Work"].waitForExistence(timeout: Self.timeout),
            "the folder's own name is back")
    }

    @MainActor
    private func rename(_ location: XCUIElement, to name: String, in app: XCUIApplication) {
        XCTAssertTrue(location.waitForExistence(timeout: Self.timeout))
        location.press(forDuration: 1)
        app.buttons["Rename Location…"].firstMatch.tap()
        let alert = app.alerts["Name Location"]
        XCTAssertTrue(alert.waitForExistence(timeout: Self.timeout))
        let field = alert.textFields.firstMatch
        field.tap()
        if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
        }
        field.typeText(name)
        alert.buttons["Save"].tap()
    }

    /// The rename alert finds a new folder that the search hides (audit 2026-11, A21).
    @MainActor
    func testANewFolderIsRenamedWhileASearchHidesIt() {
        let app = launch(state: UUID().uuidString)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Notes")
        app.buttons["New Folder"].firstMatch.tap()
        XCTAssertTrue(
            app.alerts["Rename"].waitForExistence(timeout: Self.timeout), "the alert asks a name")
    }
}

extension XCUIApplication {
    /// Whether `condition` holds within ten seconds.
    @MainActor
    func eventually(_ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: LocationsTests.timeout) == .completed
    }
}
