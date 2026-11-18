import XCTest

/// The iPhone Duo (ADR 0133), on the pinned Duo by `tools/build.sh iosuitest --duo`; the
/// iPads' and the iPhone's runs skip it. The tests see the outer display, as the simulator
/// starts closed and no tool opens it.
final class DuoTests: XCTestCase {
    private static let timeout: TimeInterval = 10

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
}
