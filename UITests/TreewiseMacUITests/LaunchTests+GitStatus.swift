import XCTest

/// A folder in a git repository shows each item's state on its icon and the branch in the
/// status bar (ADR 0149), in a repository the test makes in its root.
extension LaunchTests {
    @MainActor
    func testAChangedFileShowsItsBadgeAndTheStatusBarTheBranch() throws {
        let root = try XCTUnwrap(self.root)
        try TestGit.run(["init", "-q", "-b", "main"], in: root)
        try TestGit.run(["add", "-A"], in: root)
        try TestGit.run(["commit", "-q", "-m", "first"], in: root)
        try Data("changed".utf8).write(to: root.appendingPathComponent("Notes.md"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout))

        XCTAssertTrue(
            window.tables.images["Modified"].appeared(timeout: Self.launchTimeout),
            "the changed file has the modified badge")
        let branch = window.staticTexts["gitBranch"]
        XCTAssertTrue(branch.appeared(timeout: Self.launchTimeout), "the branch shows")
        XCTAssertEqual(branch.value as? String, "main local only")
    }

    @MainActor
    func testAFolderInTheSidebarShowsTheStateOfWhatItHolds() throws {
        let root = try XCTUnwrap(self.root)
        let letter = root.appendingPathComponent("Documents/Letter.md")
        try Data("first".utf8).write(to: letter)
        try TestGit.run(["init", "-q", "-b", "main"], in: root)
        try TestGit.run(["add", "-A"], in: root)
        try TestGit.run(["commit", "-q", "-m", "first"], in: root)
        try Data("changed".utf8).write(to: letter)
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.outlines.staticTexts["Documents"].appeared(timeout: Self.launchTimeout))

        XCTAssertTrue(
            window.outlines.images["Modified"].appeared(timeout: Self.launchTimeout),
            "Documents, which holds the changed letter, has the modified badge in the sidebar")
    }
}
