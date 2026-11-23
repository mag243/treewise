import XCTest

/// A location the system's picker gives, On My iPad, whose files the Files app's provider
/// keeps: Move to Trash moves an item to its Trash, and the next operation runs after it.
final class OnMyIPadTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    func testMoveToTrashInOnMyIPadTrashesAndTheNextOperationRuns() {
        let app = launch(state: UUID().uuidString, fixture: false)
        addOnMyIPad(in: app)
        let trashed = "Trash \(UUID().uuidString.prefix(8))"
        makeFolder(trashed, in: app)

        moveToTrash(trashed, in: app)

        XCTAssertTrue(
            app.eventually { !self.row(trashed, in: app).exists },
            "moved to the Trash; alerts: \(app.alerts.count)")
        let next = "Next \(UUID().uuidString.prefix(8))"
        makeFolder(next, in: app)
        XCTAssertTrue(row(next, in: app).waitForExistence(timeout: Self.timeout), "it runs")

        // On My iPad outlives the test: the folder it made goes to the Trash too.
        moveToTrash(next, in: app)
        XCTAssertTrue(app.eventually { !self.row(next, in: app).exists }, "cleaned up")
    }

    /// A favorite whose location was removed and added again is a favorite again, and is
    /// removed as any other.
    @MainActor
    func testAFavoriteOfALocationAddedAgainIsRemoved() {
        let app = launch(state: UUID().uuidString, fixture: false)
        addOnMyIPad(in: app)
        let folder = "Favorite \(UUID().uuidString.prefix(8))"
        makeFolder(folder, in: app)
        row(folder, in: app).press(forDuration: 1)
        app.buttons["Add to Favorites"].firstMatch.tap()
        let favorite = sidebar(of: app).staticTexts[folder]
        XCTAssertTrue(favorite.waitForExistence(timeout: Self.timeout), "in Favorites")

        let location = sidebar(of: app).staticTexts["On My iPad"]
        location.press(forDuration: 1)
        app.buttons["Remove Location"].firstMatch.tap()
        XCTAssertTrue(app.eventually { !location.exists }, "the location is removed")
        addOnMyIPad(in: app)
        XCTAssertTrue(favorite.waitForExistence(timeout: Self.timeout), "a favorite again")

        swipeLeft(favorite)
        // A swipe across the whole row removes it at once, as on iOS 27; a shorter one shows
        // the button.
        let remove = app.buttons["Remove from Favorites"].firstMatch
        if remove.waitForExistence(timeout: 2) { remove.tap() }

        XCTAssertTrue(app.eventually { !favorite.exists }, "removed")
        XCTAssertEqual(app.state, .runningForeground, "still running")
        moveToTrash(folder, in: app)
    }

    /// A row of the folder shown, not a favorite of the same name in the sidebar.
    @MainActor
    private func folderRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.collectionViews["folderTable"].staticTexts[name].firstMatch
    }

    @MainActor
    private func moveToTrash(_ name: String, in app: XCUIApplication) {
        folderRow(name, in: app).press(forDuration: 1)
        app.buttons["Move to Trash"].firstMatch.tap()
    }

    /// Adds On My iPad itself as a location through the picker, and opens it.
    @MainActor
    private func addOnMyIPad(in app: XCUIApplication) {
        let add = app.buttons["Add Location"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: Self.timeout))
        add.tap()
        let onMyIPad = app.staticTexts["On My iPad"].firstMatch
        XCTAssertTrue(onMyIPad.waitForExistence(timeout: Self.timeout), "the picker opens")
        onMyIPad.tap()
        // The picker's own Open, named so on iOS 27, where the app behind it has a button of
        // that title too; on iOS 18 it has only its title.
        var open = app.buttons["DOCPicker.actionButton"].firstMatch
        if !open.waitForExistence(timeout: Self.timeout / 2) {
            open = app.buttons["Open"].firstMatch
        }
        XCTAssertTrue(open.waitForExistence(timeout: Self.timeout), "the picker's Open")
        open.tap()
        let location = sidebar(of: app).staticTexts["On My iPad"]
        XCTAssertTrue(location.waitForExistence(timeout: Self.timeout), "the location")
        location.tap()
    }

    @MainActor
    private func makeFolder(_ name: String, in app: XCUIApplication) {
        app.buttons["New Folder"].firstMatch.tap()
        let sheet = app.navigationBars["New Folder"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout))
        app.textFields["name"].typeText(name)
        sheet.buttons["Create"].tap()
    }
}
