import XCTest

/// A drop on a folder in the sidebar after resting on it, so that spring-loading opens it
/// first (ADR 0003).
extension LaunchTests {
    /// Longer than the sidebar's spring-loading delay (`SidebarSpringLoading.delay`).
    private static let restLongerThanSpringLoading: TimeInterval = 1.6
    private static let pressBeforeDragging: TimeInterval = 0.6

    /// A folder without subfolders opens with nothing to show; the drop on it still lands.
    @MainActor
    func testDroppingOnAnEmptyFolderInTheSidebarAfterRestingOnIt() throws {
        let root = try XCTUnwrap(self.root)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Empty"), withIntermediateDirectories: false)
        let app = try launchApp()
        let window = app.windows.firstMatch
        // Into a folder and back, so the sidebar opens down to the folder shown.
        let documents = window.tables.staticTexts["Documents"]
        XCTAssertTrue(documents.appeared(timeout: Self.launchTimeout))
        documents.doubleClick()
        app.typeKey("[", modifierFlags: .command)
        let notes = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        let empty = window.outlines.staticTexts["Empty"]
        XCTAssertTrue(empty.appeared(timeout: Self.launchTimeout), "the sidebar shows the folder")

        let centre = CGVector(dx: 0.5, dy: 0.5)
        notes.coordinate(withNormalizedOffset: centre).click(
            forDuration: Self.pressBeforeDragging,
            thenDragTo: empty.coordinate(withNormalizedOffset: centre),
            withVelocity: .slow, thenHoldForDuration: Self.restLongerThanSpringLoading)

        XCTAssertTrue(notes.disappeared(timeout: Self.launchTimeout), "the file moved")
        let moved = root.appendingPathComponent("Empty/Notes.md")
        XCTAssertTrue(
            app.eventually { FileManager.default.fileExists(atPath: moved.path) },
            "the file is in the folder")
    }
}
