import XCTest

/// The UI review (ADR 0103): walks the screens in the system's appearance, or in each one
/// `UIREVIEW_APPEARANCES` names (`light,dark`), keeps a screenshot of each and the findings
/// of `UIReviewChecks` beside it. Run on the official build, with its
/// add-ons, by `tools/build.sh uireview`, which makes the report and ends red on a finding;
/// `apptest` and `ci` skip this class. A finding does not fail the walk, so every screen is
/// taken; only a walk that cannot go on fails.
final class UIReviewTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// How long a screen settles before it is looked at: a card opens and the list scrolls
    /// to it with an animation that offers nothing to wait for. The review tests no
    /// behaviour, so a fixed pause is fine, as for the download page's screenshots.
    private static let settle: TimeInterval = 1
    private static let settingsWindow = "TreewiseSettings"
    private static let tabs = ["General", "Names", "Templates", "Add-ons"]

    private var root: URL?

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreewiseUIReview-\(UUID().uuidString)", isDirectory: true)
        for path in [
            "Projects", "Documents", "Administration/2026/Tax/Appeals",
            "Administration/2026/Receipts", "Administration/2027/Receipts",
        ] {
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        try Data("notes".utf8).write(to: folder.appendingPathComponent("Notes.md"))
        root = folder
        try seedTemplates(beside: folder)
    }

    override func tearDownWithError() throws {
        MainActor.assumeIsolated { XCUIApplication().quit() }
        guard let root else { return }
        try? FileManager.default.removeItem(at: settingsFolder(of: root))
        try FileManager.default.removeItem(at: root)
    }

    /// The appearances to walk in: those `tools/build.sh uireview all` names, else the
    /// system's own, as `nil`.
    private static var appearances: [String?] {
        let named = ProcessInfo.processInfo.environment["UIREVIEW_APPEARANCES"] ?? ""
        let list = named.split(separator: ",").map { String($0) }
        return list.isEmpty ? [nil] : list
    }

    @MainActor
    func testSettings() throws {
        for appearance in Self.appearances {
            try settings(appearance: appearance)
            XCUIApplication().terminate()
        }
    }

    // MARK: - Walks

    /// Every tab of Settings; every add-on card open in turn and back to the first, then
    /// each paid one's trial started from its card; and the Templates tab with the add-on.
    @MainActor
    private func settings(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows[Self.settingsWindow]
        XCTAssertTrue(window.waitForExistence(timeout: Self.timeout), "Settings opens")
        for tab in Self.tabs {
            open(tab, in: window)
            review(
                window, as: "settings-\(slug(tab))", appearance: appearance, listsSpanThePane: true)
        }
        try reviewCards(in: window, appearance: appearance, startingTrials: false)
        try reviewCards(in: window, appearance: appearance, startingTrials: true)
        open("Templates", in: window)
        let list = window.tables["templatesList"]
        let year = list.textFields.matching(NSPredicate(format: "value == %@", "Household Year"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout), "the templates are listed")
        year.click()
        let tree = window.outlines["templateTreeEditor"]
        let tax = tree.textFields.matching(NSPredicate(format: "value == %@", "Tax")).firstMatch
        XCTAssertTrue(tax.waitForExistence(timeout: Self.timeout), "its tree shows")
        tax.click()
        settleScreen()
        review(
            window, as: "settings-templates-trial", appearance: appearance, listsSpanThePane: true)
    }

    /// Opens each card of the Add-ons tab in turn, and the first again after the last.
    /// `startingTrials` starts each paid add-on's trial from its card, as the user does.
    @MainActor
    private func reviewCards(in window: XCUIElement, appearance: String?, startingTrials: Bool)
        throws
    {
        open("Add-ons", in: window)
        // Each card is a group named after its add-on.
        let list = window.tables.firstMatch
        XCTAssertTrue(list.groups.firstMatch.waitForExistence(timeout: Self.timeout), "cards show")
        let name = startingTrials ? "settings-add-ons-trial" : "settings-add-ons"
        for card in cardNames(in: list) {
            choose(card, in: list)
            let tryIt = window.buttons["Try for 14 Days"]
            if startingTrials, tryIt.exists {
                tryIt.click()
                settleScreen()
            }
            review(
                window, as: "\(name)-\(slug(card))", appearance: appearance,
                listsSpanThePane: true)
        }
        // Back to the first card there is now: a trial can take a free card's place.
        if let first = cardNames(in: list).first {
            choose(first, in: list)
            review(
                window, as: "\(name)-\(slug(first))-again", appearance: appearance,
                listsSpanThePane: true)
        }
    }

    /// The cards of the list, each a group named after its add-on.
    @MainActor
    private func cardNames(in list: XCUIElement) -> [String] {
        list.groups.allElementsBoundByIndex
            .filter { !$0.label.isEmpty && $0.staticTexts[$0.label].exists }.map(\.label)
    }

    @MainActor
    private func choose(_ card: String, in list: XCUIElement) {
        let title = list.groups[card].staticTexts[card]
        XCTAssertTrue(title.waitForExistence(timeout: Self.timeout), "\(card) shows")
        title.click()
        settleScreen()
    }

    // MARK: - Looking

    @MainActor
    private func open(_ tab: String, in window: XCUIElement) {
        let button = window.toolbars.buttons[tab]
        XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "Settings has \(tab)")
        button.click()
        settleScreen()
    }

    /// Keeps a screenshot of `window` and what the checks found on it, both named `name`
    /// and the variant, for the report.
    @MainActor
    private func review(
        _ window: XCUIElement, as name: String, appearance: String?, listsSpanThePane: Bool = false
    ) {
        let full = appearance.map { "\(name)-\($0)" } ?? name
        let screenshot = XCTAttachment(screenshot: window.screenshot())
        screenshot.name = "uireview-\(full)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        var found: [UIReviewFinding] = []
        do {
            found = UIReviewChecks.findings(
                in: try window.snapshot(), listsSpanThePane: listsSpanThePane)
        } catch {
            found = [UIReviewFinding(check: "snapshot", element: "window", detail: "\(error)")]
        }
        let findings = XCTAttachment(
            data: (try? JSONEncoder().encode(found)) ?? Data(), uniformTypeIdentifier: "public.json"
        )
        findings.name = "uireview-\(full).findings"
        findings.lifetime = .keepAlways
        add(findings)
    }

    // MARK: - Setting up

    @MainActor
    private func launch(appearance: String?) throws -> XCUIApplication {
        let app = XCUIApplication()
        let root = try XCTUnwrap(root)
        app.launchArguments =
            [
                "-TreewiseRoot", root.path, "-ApplePersistenceIgnoreState", "YES",
            ] + (appearance.map { ["-TreewiseAppearance", $0] } ?? [])
        app.launch()
        XCTAssertTrue(
            app.tables.staticTexts["Notes.md"].waitForExistence(timeout: Self.timeout),
            "the window shows its folder")
        return app
    }

    private func settleScreen() {
        Thread.sleep(forTimeInterval: Self.settle)
    }

    private func slug(_ text: String) -> String {
        text.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
    }

    /// Where the app keeps a UI test's settings: beside its root, named after it.
    private func settingsFolder(of root: URL) -> URL {
        root.deletingLastPathComponent().appendingPathComponent(
            root.lastPathComponent + "-folder-settings", isDirectory: true)
    }

    /// Two invented templates, one with a year and name settings, so the Templates tab
    /// shows a list, a tree and the line of name settings.
    private func seedTemplates(beside root: URL) throws {
        let folder = settingsFolder(of: root).appendingPathComponent("Templates")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let year = """
            {"format": 1, "name": "Household Year", "root": {"name": "{year}", "folders": [
              {"name": "Tax", "names": {"enabledModules": ["me.m-domain.treewise.folder-pattern"],
                "moduleOrder": [], "patterns": {
                  "me.m-domain.treewise.folder-pattern": "{year} Tax {seq}"}}},
              {"name": "Receipts"}, {"name": "Insurance"}]}}
            """
        let client = """
            {"format": 1, "name": "Client", "root": {"name": "{text}", "folders": [
              {"name": "Contract"}, {"name": "Invoices"}]}}
            """
        try Data(year.utf8).write(to: folder.appendingPathComponent("year.json"))
        try Data(client.utf8).write(to: folder.appendingPathComponent("client.json"))
    }
}
