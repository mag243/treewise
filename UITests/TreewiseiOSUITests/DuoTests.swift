import XCTest

/// The iPhone Duo (ADR 0133), on the pinned Duo by `tools/build.sh iosuitest --duo`; the
/// iPads' and the iPhone's runs skip it. The tests see the outer display: the simulator starts
/// folded shut, and `tools/build.sh duo close` folds it shut again (ADR 0145). It is also the
/// one iPhone the UI tests run on iOS 27.
final class DuoTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// How long the keyboard has to come up with a menu, which it does as the menu opens.
    private static let keyboardTimeout: TimeInterval = 3

    override func setUp() {
        continueAfterFailure = false
    }

    /// The outer display's width is compact, so it shows the iPhone's layout (ADR 0132).
    @MainActor
    func testTheOuterDisplayShowsTheIPhonesLayout() {
        let app = launch(state: UUID().uuidString)
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

        XCTAssertTrue(app.buttons["moreMenu"].firstMatch.exists, "the one menu")
        XCTAssertFalse(sidebar(of: app).exists, "no sidebar beside the folder")
    }

    /// A file's context menu leaves the keyboard down: on iOS 27 a menu brings up the input
    /// view of the first responder, the list, which is the keyboard unless the list has one
    /// of its own.
    @MainActor
    func testAContextMenuLeavesTheKeyboardDown() {
        let app = launch(state: UUID().uuidString)
        let notes = row("Notes.md", in: app)
        XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))

        notes.press(forDuration: 1)
        XCTAssertTrue(
            app.buttons["Rename"].firstMatch.waitForExistence(timeout: Self.timeout), "the menu")
        XCTAssertFalse(
            app.keyboards.firstMatch.waitForExistence(timeout: Self.keyboardTimeout),
            "no keyboard with the menu")
    }
}
