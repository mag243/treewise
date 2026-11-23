import XCTest

/// The table's columns, chosen from the "…" heading and resized by dragging the line
/// between two headings, and the toolbar's Undo button (ADR 0125).
final class TableColumnsTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// How far the tests drag a line between headings.
    private static let dragDistance: CGFloat = 80

    override func setUp() async throws {
        continueAfterFailure = false
        // The sidebar stays beside the folder in landscape, with the table's headings.
        await MainActor.run { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    @MainActor
    private func openDocuments(_ state: String) -> XCUIApplication {
        let app = launch(state: state)
        sidebar(of: app).staticTexts["Documents"].tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    func testTheColumnMenuHidesAColumnAndARelaunchKeepsItHidden() {
        let state = UUID().uuidString
        let app = openDocuments(state)
        XCTAssertTrue(app.buttons["Kind"].firstMatch.exists)

        app.buttons["columns"].firstMatch.tap()
        app.buttons["Kind"].firstMatch.tap()
        XCTAssertTrue(app.eventually { !app.buttons["Kind"].firstMatch.exists }, "hidden")
        app.terminate()

        let again = openDocuments(state)
        XCTAssertFalse(again.buttons["Kind"].firstMatch.exists, "still hidden")
        XCTAssertTrue(again.buttons["Size"].firstMatch.exists)
    }

    @MainActor
    func testTheDateCreatedShowsOnlyOnceChosen() {
        let app = openDocuments(UUID().uuidString)
        XCTAssertFalse(app.buttons["Date Created"].firstMatch.exists, "hidden at first")
        // Without Kind there is room for it beside the date modified on every iPad.
        app.buttons["columns"].firstMatch.tap()
        app.buttons["Kind"].firstMatch.tap()
        XCTAssertTrue(app.eventually { !app.buttons["Kind"].firstMatch.exists })

        app.buttons["columns"].firstMatch.tap()
        app.buttons["Date Created"].firstMatch.tap()

        XCTAssertTrue(
            app.buttons["Date Created"].firstMatch.waitForExistence(timeout: Self.timeout))
    }

    /// Every column takes more room than a 13-inch iPad's folder beside the sidebar has: the
    /// table keeps its headings, the dates created and added give way, and they stay chosen
    /// (ADR 0125).
    @MainActor
    func testChosenColumnsWithoutRoomGiveWayAndStayChosen() {
        let app = openDocuments(UUID().uuidString)
        for column in ["Date Created", "Date Added"] {
            app.buttons["columns"].firstMatch.tap()
            app.buttons[column].firstMatch.tap()
        }

        XCTAssertTrue(app.buttons["Kind"].firstMatch.waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(app.buttons["Date Modified"].firstMatch.exists, "the headings stay")
        XCTAssertFalse(app.buttons["Date Added"].firstMatch.exists, "the date added gives way")
        app.buttons["columns"].firstMatch.tap()
        // iOS 27 adds the item's subtitle, "No room in this width", to its label.
        let dateAdded = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Date Added'"))
            .firstMatch
        XCTAssertTrue(dateAdded.waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(dateAdded.isSelected, "still chosen")
    }

    @MainActor
    func testDraggingTheLineBeforeAColumnToTheLeftWidensItAndADoubleTapGivesItsWidthBack() {
        let app = openDocuments(UUID().uuidString)
        // Without Kind the name has room to give; a column widens no further than that.
        app.buttons["columns"].firstMatch.tap()
        app.buttons["Kind"].firstMatch.tap()
        let date = app.buttons["Date Modified"].firstMatch
        XCTAssertTrue(app.eventually { !app.buttons["Kind"].firstMatch.exists })
        let before = date.frame.minX
        let line = app.otherElements["resize-after-name"].firstMatch
        XCTAssertTrue(line.exists)

        let start = line.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: -Self.dragDistance, dy: 0)))
        XCTAssertTrue(
            app.eventually { date.frame.minX < before - Self.dragDistance / 2 },
            "Date Modified is wider, so it starts further left: from \(before) to "
                + "\(date.frame.minX), the line at \(line.frame)")

        line.doubleTap()
        XCTAssertTrue(app.eventually { abs(date.frame.minX - before) < 2 }, "back to its width")
    }

    @MainActor
    func testUndoInTheToolbarTurnsARenameBackAndItsLongPressRedoesIt() {
        let app = openDocuments(UUID().uuidString)
        let undo = app.buttons["undo"].firstMatch
        XCTAssertFalse(undo.isEnabled, "nothing to undo yet")

        row("Notes.md", in: app).press(forDuration: 1)
        app.buttons["Rename"].firstMatch.tap()
        let sheet = app.navigationBars["Rename"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout))
        // The name is selected without its extension, as on the Mac.
        app.textFields["name"].typeText("Memo")
        sheet.buttons["Rename"].tap()
        XCTAssertTrue(row("Memo.md", in: app).waitForExistence(timeout: Self.timeout))

        XCTAssertTrue(app.eventually { undo.isEnabled })
        undo.tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout), "undone")

        undo.press(forDuration: 1)
        let redo = app.buttons["Redo Rename"].firstMatch
        XCTAssertTrue(redo.waitForExistence(timeout: Self.timeout), "a long press offers Redo")
        redo.tap()
        XCTAssertTrue(row("Memo.md", in: app).waitForExistence(timeout: Self.timeout), "redone")
    }
}
