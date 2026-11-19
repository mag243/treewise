import XCTest

/// The UI review (ADR 0103): walks the screens in the system's appearance, or in each one
/// `UIREVIEW_APPEARANCES` names (`light,dark`), keeps a screenshot of each and the findings
/// of `UIReviewChecks` beside it. Run on the official build, with its
/// add-ons, by `tools/build.sh uireview`, which makes the report and ends red on a finding;
/// `apptest` and `ci` skip this class. A finding does not fail the walk, so every screen is
/// taken; only a walk that cannot go on fails.
final class UIReviewTests: XCTestCase {
    static let timeout: TimeInterval = 10
    /// How long a screen settles before it is looked at: a card opens and the list scrolls
    /// to it with an animation that offers nothing to wait for. The review tests no
    /// behaviour, so a fixed pause is fine, as for the download page's screenshots.
    private static let settle: TimeInterval = 1
    static let settingsWindow = "TreewiseSettings"

    private(set) var root: URL?

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreewiseUIReview-\(UUID().uuidString)", isDirectory: true)
        for path in [
            "Projects/Client A/Contract", "Projects/Client A/Invoices", "Documents/Taxes",
            "Administration/2026/Tax/Appeals", "Administration/2026/Receipts",
            "Administration/2027/Receipts", "Administration/2028",
        ] {
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        for file in [
            "Notes.md", "Documents/Taxes/2026-01-15 Invoice Acme.pdf",
            "Documents/Taxes/2026-02-15 Invoice Acme.pdf", "Documents/Taxes/scan0001.pdf",
            "Documents/Taxes/Payment reminder.pdf",
        ] {
            try Data("invented".utf8).write(to: folder.appendingPathComponent(file))
        }
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

    /// Runs `walk` in each appearance asked for, with the app quit between them.
    @MainActor
    func eachAppearance(_ walk: (String?) throws -> Void) throws {
        for appearance in Self.appearances {
            try walk(appearance)
            XCUIApplication().terminate()
        }
    }

    // MARK: - Looking

    @MainActor
    func open(_ tab: String, in window: XCUIElement) {
        let button = window.toolbars.buttons[tab]
        XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "Settings has \(tab)")
        press(button)
        settleScreen()
    }

    /// Keeps a screenshot of `window` and what the checks found on it, both named `name`
    /// and the variant, for the report.
    @MainActor
    func review(
        _ window: XCUIElement, as name: String, appearance: String?, isSettingsPane: Bool = false,
        also more: [UIReviewFinding] = []
    ) {
        let full = appearance.map { "\(name)-\($0)" } ?? name
        let screenshot = XCTAttachment(screenshot: window.screenshot())
        screenshot.name = "uireview-\(full)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        var found: [UIReviewFinding] = []
        // A sheet on the window is what is looked at; the window under it is covered.
        let sheet = window.sheets.firstMatch
        let looked = sheet.exists ? sheet : window
        do {
            found = UIReviewChecks.findings(
                in: try looked.snapshot(), isSettingsPane: isSettingsPane && !sheet.exists)
        } catch {
            found = [UIReviewFinding(check: "snapshot", element: "window", detail: "\(error)")]
        }
        found += more
        let findings = XCTAttachment(
            data: (try? JSONEncoder().encode(found)) ?? Data(), uniformTypeIdentifier: "public.json"
        )
        findings.name = "uireview-\(full).findings"
        findings.lifetime = .keepAlways
        add(findings)
    }

    // MARK: - Pressing

    /// What a press does to an element.
    enum Press {
        case click, rightClick, hover
    }

    /// How far one turn of the scroll wheel moves a list, and how many turns are tried.
    private static let scrollStep: CGFloat = 40
    private static let mostScrollSteps = 30

    /// Presses `element` as a person would: in `list`, scrolled into view first, and only
    /// when the pointer can reach it where it shows. One out of view, or under an edge or
    /// another window, fails the walk rather than be pressed elsewhere.
    @MainActor
    func press(_ element: XCUIElement, in list: XCUIElement? = nil, _ how: Press = .click) {
        if let list { scroll(element, intoViewOf: list) }
        guard element.isHittable else {
            XCTFail("\(element) cannot be reached where it shows, so it is not pressed")
            return
        }
        switch how {
        case .click: element.click()
        case .rightClick: element.rightClick()
        case .hover: element.hover()
        }
    }

    /// Turns the scroll wheel over `list` until `element` shows whole in it.
    @MainActor
    private func scroll(_ element: XCUIElement, intoViewOf list: XCUIElement) {
        let shown = visibleFrame(of: list)
        var step = element.frame.midY > shown.midY ? -Self.scrollStep : Self.scrollStep
        for _ in 0..<Self.mostScrollSteps {
            guard !shown.contains(element.frame) else { return }
            let before = abs(element.frame.midY - shown.midY)
            list.scroll(byDeltaX: 0, deltaY: step)
            // The wheel's direction follows the system's setting; turn the other way when
            // the element went further off.
            if abs(element.frame.midY - shown.midY) > before { step = -step }
        }
    }

    /// What shows of `list`: a table's frame holds all its rows, so the scroll view around
    /// it, which starts where it starts, is what shows.
    @MainActor
    private func visibleFrame(of list: XCUIElement) -> CGRect {
        let frame = list.frame
        let around = XCUIApplication().scrollViews.allElementsBoundByIndex.map(\.frame).first {
            abs($0.minX - frame.minX) <= 2 && $0.intersects(frame) && $0.height <= frame.height
        }
        return around ?? frame
    }

    // MARK: - Setting up

    @MainActor
    func launch(appearance: String?) throws -> XCUIApplication {
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

    func settleScreen() {
        Thread.sleep(forTimeInterval: Self.settle)
    }

    func slug(_ text: String) -> String {
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
              {"name": "Tax", "names": {"enabledModules": ["me.m-domain.treewise.file-name-patterns"],
                "moduleOrder": [], "patterns": {
                  "me.m-domain.treewise.file-name-patterns": "{year} Tax {seq}"}}},
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
