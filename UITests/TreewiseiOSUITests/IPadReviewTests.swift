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
    private static let emptyPoint = CGVector(dx: 0.5, dy: 0.97)

    private static let orientations: [(name: String, orientation: UIDeviceOrientation)] = [
        ("landscape", .landscapeLeft), ("portrait", .portrait),
    ]

    private static var appearances: [String] {
        let named = ProcessInfo.processInfo.environment["UIREVIEW_APPEARANCES"] ?? ""
        let list = named.split(separator: ",").map { String($0) }
        return list.isEmpty ? ["light"] : list
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
                try walk("\(name)-\(appearance)")
            }
        }
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    @MainActor
    private func launch(state: String, fixture: Bool, removing: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseTestState", state, "-TreewiseTestFixture", fixture ? "YES" : "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        if let removing { app.launchArguments += ["-TreewiseTestRemove", removing] }
        app.launch()
        return app
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
            review(app, as: "view-menu", variant: variant)
            closeMenu(in: app)

            notes.press(forDuration: Self.longPress)
            review(app, as: "context-menu", variant: variant)
            closeMenu(in: app)

            app.buttons["New Folder"].firstMatch.tap()
            let alert = app.alerts["Rename"]
            XCTAssertTrue(alert.waitForExistence(timeout: Self.timeout))
            review(app, as: "rename", variant: variant)
            alert.buttons["Cancel"].tap()

            notes.tap()
            XCTAssertTrue(
                app.otherElements["QLPreviewControllerView"].waitForExistence(
                    timeout: Self.timeout))
            review(app, as: "quick-look", variant: variant)
            app.terminate()
        }
    }

    // MARK: - Looking

    @MainActor
    private func closeMenu(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: Self.emptyPoint).tap()
        settleScreen()
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
            found = UIReviewChecks.findings(in: try app.snapshot())
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
