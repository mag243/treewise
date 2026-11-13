import XCTest

/// The smoke test of PLAN.md §9.5: open, tab, window beside, drag, undo, in a
/// temporary folder (`-TreewiseRoot`), so the user's own folders are never shown.
final class SmokeTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// How long the pointer holds on the row before dragging, and over the
    /// target before dropping, so AppKit starts the drag and picks the target.
    private static let hold: TimeInterval = 0.5

    private var root: URL?

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreewiseSmoke-\(UUID().uuidString)", isDirectory: true)
        for name in ["Projects", "Documents"] {
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try Data("notes".utf8).write(to: folder.appendingPathComponent("Notes.md"))
        root = folder
    }

    /// Quits the app before its folder goes, so the next test starts it at once.
    override func tearDownWithError() throws {
        MainActor.assumeIsolated { XCUIApplication().quit() }
        if let root {
            OpenedLog.check(root: root)
            try FileManager.default.removeItem(at: root)
        }
    }

    private func exists(_ path: String) throws -> Bool {
        FileManager.default.fileExists(
            atPath: try XCTUnwrap(root).appendingPathComponent(path).path)
    }

    /// Waits until whether `path` exists is `toExist`.
    private func wait(for path: String, toExist: Bool) throws -> Bool {
        let check = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in
                (try? self?.exists(path)) == toExist
            }, object: nil)
        return XCTWaiter.wait(for: [check], timeout: Self.timeout) == .completed
    }

    @MainActor
    func testOpenTabWindowBesideDragUndo() throws {
        let app = XCUIApplication()
        let root = try XCTUnwrap(root)
        app.launchArguments =
            ["-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "YES"]
            + OpenedLog.arguments(for: root)
        app.launch()
        let notes = app.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.timeout))

        app.tables.staticTexts["Documents"].doubleClick()
        XCTAssertTrue(notes.disappeared(timeout: Self.timeout), "open: Documents is empty")
        app.typeKey("[", modifierFlags: .command)
        XCTAssertTrue(notes.appeared(timeout: Self.timeout), "back in the folder")

        app.typeKey("t", modifierFlags: .command)
        XCTAssertTrue(app.waitForSecondTab(), "tab")
        // The tab behind may count as a window, so wait for one more than now.
        let before = app.windows.count
        app.typeKey("n", modifierFlags: [.command, .option])
        XCTAssertTrue(app.eventually { app.windows.count > before }, "beside")
        // A tab behind another has the same frame, so the first and last by x
        // are the left and the right window.
        let windows = app.windows.allElementsBoundByIndex.sorted { $0.frame.minX < $1.frame.minX }
        let left = try XCTUnwrap(windows.first)
        let right = try XCTUnwrap(windows.last)
        XCTAssertTrue(right.tables.staticTexts["Notes.md"].appeared(timeout: Self.timeout))

        // `click(forDuration:thenDragTo:)` is the mouse drag; `press` is for touch.
        let centre = CGVector(dx: 0.5, dy: 0.5)
        right.tables.staticTexts["Notes.md"].coordinate(withNormalizedOffset: centre).click(
            forDuration: Self.hold,
            thenDragTo: left.tables.staticTexts["Projects"].coordinate(
                withNormalizedOffset: centre),
            withVelocity: .slow, thenHoldForDuration: Self.hold)
        XCTAssertTrue(
            try wait(for: "Projects/Notes.md", toExist: true), "drag: moved into Projects")
        XCTAssertFalse(try exists("Notes.md"))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(try wait(for: "Notes.md", toExist: true), "undo: back where it was")
        XCTAssertFalse(try exists("Projects/Notes.md"))
    }
}
