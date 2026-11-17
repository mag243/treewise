import XCTest

/// The iPad's UI review (ADR 0115): walks the screens in landscape and portrait, in light or
/// in each appearance `UIREVIEW_APPEARANCES` names (`light,dark`), keeps a screenshot of each
/// and the findings of `UIReviewChecks` beside it. Run by `tools/build.sh iosreview`, which
/// makes the report; `iosuitest` skips this class. A finding does not fail the walk.
final class IPadReviewTests: XCTestCase {
    static let timeout: TimeInterval = 10
    /// How long a screen settles before it is looked at: a menu or a sheet opens with an
    /// animation that offers nothing to wait for. The review tests no behaviour.
    private static let settle: TimeInterval = 1
    /// How long a press opens a row's context menu.
    private static let longPress: TimeInterval = 1
    /// A point of the screen with nothing on it to tap, which closes a menu.
    /// Above the on-screen keyboard iPadOS 27's simulator brings in with a menu, and beside
    /// the menus.
    private static let emptyPoint = CGVector(dx: 0.3, dy: 0.5)

    private static let orientations: [(name: String, orientation: UIDeviceOrientation)] = [
        ("landscape", .landscapeLeft), ("portrait", .portrait),
    ]

    private static var appearances: [String] {
        let named = ProcessInfo.processInfo.environment["UIREVIEW_APPEARANCES"] ?? ""
        let list = named.split(separator: ",").map { String($0) }
        return list.isEmpty ? ["light"] : list
    }

    /// The device's name in the screens' names, as `UIREVIEW_DEVICE` gives it: empty on the
    /// pinned iPad, `11inch` on the smaller one (ADR 0115).
    private static var device: String {
        ProcessInfo.processInfo.environment["UIREVIEW_DEVICE"] ?? ""
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// Runs `walk` in each orientation and appearance, with its variant's name.
    @MainActor
    private func eachVariant(_ walk: (String) throws -> Void) throws {
        for appearance in Self.appearances {
            XCUIDevice.shared.appearance = appearance == "dark" ? .dark : .light
            for (name, orientation) in Self.orientations {
                XCUIDevice.shared.orientation = orientation
                let place = Self.device.isEmpty ? name : "\(name)-\(Self.device)"
                try walk("\(place)-\(appearance)")
            }
        }
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    // MARK: - Screens

    @MainActor
    func testStart() throws {
        try eachVariant { variant in
            let app = launch(state: UUID().uuidString, fixture: false)
            XCTAssertTrue(
                app.buttons["Add Location"].firstMatch.waitForExistence(timeout: Self.timeout))
            review(app, as: "start", variant: variant)
            app.terminate()
        }
    }

    /// The sidebar with a folder out of reach, the table, the View menu, a row's context
    /// menu, the rename alert and Quick Look.
    @MainActor
    func testBrowser() throws {
        try eachVariant { variant in
            let state = UUID().uuidString
            launch(state: state, fixture: true).terminate()
            let app = launch(state: state, fixture: true, removing: "Work")
            let notes = app.staticTexts["Notes.md"].firstMatch
            XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))
            review(app, as: "browser", variant: variant)

            app.buttons["View"].firstMatch.tap()
            let descending = app.buttons["Descending"].firstMatch
            XCTAssertTrue(descending.waitForExistence(timeout: Self.timeout), "the View menu")
            review(app, as: "view-menu", variant: variant)
            closeMenu(showing: descending, in: app)

            app.buttons["New Folder"].firstMatch.tap()
            let sheet = app.navigationBars["New Folder"]
            XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout))
            review(app, as: "rename", variant: variant)
            sheet.buttons["Cancel"].tap()

            notes.tap()
            XCTAssertTrue(
                app.otherElements["QLPreviewControllerView"].waitForExistence(
                    timeout: Self.timeout))
            review(app, as: "quick-look", variant: variant)
            app.terminate()

            // On iPadOS 27 an app is not reported idle while a row's menu is open, Apple's own
            // too, and each step waits a minute (ADR 0115): this is the walk's one context
            // menu, looked at last in a run of its own, which ends without closing it.
            let menuApp = launch(state: state, fixture: true, removing: "Work")
            let row = menuApp.staticTexts["Notes.md"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.timeout))
            row.press(forDuration: Self.longPress)
            XCTAssertTrue(
                menuApp.buttons["Rename"].firstMatch.waitForExistence(timeout: Self.timeout),
                "the row's menu")
            review(menuApp, as: "context-menu", variant: variant)
            menuApp.terminate()
        }
    }

    /// The name overview with its coloured pattern and proposal, and the rename sheet with
    /// the proposals beneath the name (ADR 0129, 0130).
    @MainActor
    func testNames() throws {
        try eachVariant { variant in
            let app = launch(state: UUID().uuidString, fixture: true)
            // The app opens at the first location, Documents; in portrait the sidebar hides.
            let notes = app.staticTexts["Notes.md"].firstMatch
            XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))

            perform("Suggest Names…", on: "Notes.md", in: app)
            let proposal = app.textFields["proposal-Notes.md"].firstMatch
            XCTAssertTrue(proposal.waitForExistence(timeout: Self.timeout))
            review(app, as: "name-overview", variant: variant)
            app.navigationBars.buttons["Cancel"].firstMatch.tap()
            toolbarButton("Done", in: app).tap()

            XCTAssertTrue(notes.waitForExistence(timeout: Self.timeout))
            perform("Rename with Suggestions…", on: "Notes.md", in: app)
            XCTAssertTrue(
                app.buttons["suggestion-0"].waitForExistence(timeout: Self.timeout))
            app.buttons["suggestion-0"].tap()
            review(app, as: "rename-suggestions", variant: variant)
            app.terminate()
        }
    }

    /// Settings with its saved patterns, and the sidebar with a favorite (ADR 0130, 0131).
    @MainActor
    func testSettings() throws {
        try eachVariant { variant in
            let app = launch(state: UUID().uuidString, fixture: true)
            let projects = app.staticTexts["Projects"].firstMatch
            XCTAssertTrue(projects.waitForExistence(timeout: Self.timeout))
            perform("Add to Favorites", on: "Projects", in: app)
            toolbarButton("Done", in: app).tap()
            review(app, as: "favorites", variant: variant)

            // In portrait the sidebar, with the gear, shows over the folder when asked.
            if !app.buttons["settings"].firstMatch.isHittable {
                app.buttons["ToggleSidebar"].firstMatch.tap()
            }
            app.buttons["settings"].firstMatch.tap()
            let saved = app.buttons["savedPatterns"].firstMatch
            XCTAssertTrue(saved.waitForExistence(timeout: Self.timeout))
            review(app, as: "settings", variant: variant)
            saved.tap()
            review(app, as: "saved-patterns", variant: variant)
            app.terminate()
        }
    }

    // MARK: - Looking

    /// Closes the menu that shows `item`, and checks it is gone.
    @MainActor
    private func closeMenu(showing item: XCUIElement, in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: Self.emptyPoint).tap()
        XCTAssertTrue(app.eventually { !item.exists }, "the menu closed")
        settleScreen()
    }

    /// Performs a row's command as Select and the toolbar's Actions menu offer it, with the
    /// same commands as the row's context menu (ADR 0115). Selecting starts here; the caller
    /// ends it with Done.
    @MainActor
    private func perform(_ command: String, on name: String, in app: XCUIApplication) {
        toolbarButton("Select", in: app).tap()
        let row = app.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.timeout))
        row.tap()
        toolbarButton("Actions", in: app).tap()
        let item = app.buttons[command].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.timeout), "\(command) in Actions")
        item.tap()
    }

    /// A button of the folder's toolbar, from its overflow menu where the toolbar has no room
    /// for it, as on the 11-inch iPad in portrait.
    @MainActor
    private func toolbarButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        if button.exists { return button }
        app.buttons["OverflowBarButtonItem"].firstMatch.tap()
        XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "\(label) in the overflow")
        return button
    }

    /// Keeps a screenshot of the screen and what the checks found on it, both named
    /// `uireview-<name>-<variant>`, for the report.
    @MainActor
    private func review(_ app: XCUIApplication, as name: String, variant: String) {
        settleScreen()
        let full = "\(name)-\(variant)"
        let screenshot = XCTAttachment(image: Self.upright(XCUIScreen.main.screenshot().image))
        screenshot.name = "uireview-\(full)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        var found: [UIReviewFinding]
        do {
            found = UIReviewChecks.findings(in: try app.snapshot(), readableLines: true)
        } catch {
            found = [UIReviewFinding(check: "snapshot", element: "app", detail: "\(error)")]
        }
        let findings = XCTAttachment(
            data: (try? JSONEncoder().encode(found)) ?? Data(), uniformTypeIdentifier: "public.json"
        )
        findings.name = "uireview-\(full).findings"
        findings.lifetime = .keepAlways
        add(findings)
    }

    /// The screenshot drawn as the screen is held: the simulator keeps a landscape one's
    /// pixels in portrait with a note of how to turn them, which the report does not read.
    @MainActor
    private static func upright(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
        }
    }

    private func settleScreen() {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settle)
    }
}
