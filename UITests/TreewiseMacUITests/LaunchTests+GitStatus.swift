import XCTest

/// A folder in a git repository shows each item's state on its icon and the branch in the
/// status bar (ADR 0149), in a repository the test makes in its root.
extension LaunchTests {
    @MainActor
    func testAChangedFileShowsItsBadgeAndTheStatusBarTheBranch() throws {
        let root = try XCTUnwrap(self.root)
        try runGit(["init", "-q", "-b", "main"], in: root)
        try runGit(["add", "-A"], in: root)
        try runGit(["commit", "-q", "-m", "first"], in: root)
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

    /// Runs git in `folder`, apart from the user's own settings, with a name to commit under.
    private func runGit(_ arguments: [String], in folder: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments =
            ["-C", folder.path, "-c", "user.name=Test", "-c", "user.email=test@example.com"]
            + arguments
        process.environment = ["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "git \(arguments.joined(separator: " "))")
    }
}
