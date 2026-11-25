import XCTest

/// The UI review's walk through git status (ADR 0149): `tools/build.sh uireview git`. The
/// review's root made a repository with an item in each state: the list with its Git
/// column, the branch and the sidebar's mark, and the icon view.
extension UIReviewTests {
    @MainActor
    func testGit() throws {
        try makeRepository()
        try eachAppearance(git)
    }

    @MainActor
    private func git(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.tables.images["Modified"].waitForExistence(timeout: Self.timeout),
            "the changed file shows its badge")
        showGitColumn(in: window, app: app)
        settleScreen()
        review(window, as: "git-list", appearance: appearance)
        app.typeKey("1", modifierFlags: .command)
        settleScreen()
        review(window, as: "git-icons", appearance: appearance)
        app.typeKey("2", modifierFlags: .command)
    }

    /// Shows the Git column from the headers' menu, unless an earlier walk showed it.
    @MainActor
    private func showGitColumn(in window: XCUIElement, app: XCUIApplication) {
        let table = window.tables.firstMatch
        guard !table.buttons["Git"].exists else { return }
        table.buttons["Size"].rightClick()
        let item = app.menuItems["Git"]
        XCTAssertTrue(item.waitForExistence(timeout: Self.timeout), "the headers' menu")
        item.click()
        XCTAssertTrue(table.buttons["Git"].waitForExistence(timeout: Self.timeout), "shown")
    }

    /// Makes the root a repository: Notes.md modified, Ideas.md new, debug.log ignored, and
    /// a merge that left a scan in Documents/Taxes in conflict, on main without upstream.
    private func makeRepository() throws {
        let root = try XCTUnwrap(self.root)
        let scan = root.appendingPathComponent("Documents/Taxes/scan0001.pdf")
        try TestGit.run(["init", "-q", "-b", "main"], in: root)
        try Data("*.log\n".utf8).write(to: root.appendingPathComponent(".gitignore"))
        try TestGit.run(["add", "-A"], in: root)
        try TestGit.run(["commit", "-q", "-m", "first"], in: root)
        try TestGit.run(["switch", "-q", "-c", "other"], in: root)
        try Data("theirs".utf8).write(to: scan)
        try TestGit.run(["commit", "-q", "-am", "theirs"], in: root)
        try TestGit.run(["switch", "-q", "main"], in: root)
        try Data("ours".utf8).write(to: scan)
        try TestGit.run(["commit", "-q", "-am", "ours"], in: root)
        try TestGit.run(["merge", "-q", "other"], in: root, allowingFailure: true)
        try Data("changed".utf8).write(to: root.appendingPathComponent("Notes.md"))
        try Data("invented".utf8).write(to: root.appendingPathComponent("Ideas.md"))
        try Data("invented".utf8).write(to: root.appendingPathComponent("debug.log"))
    }
}
