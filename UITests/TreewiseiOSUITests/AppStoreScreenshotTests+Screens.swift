import XCTest

/// The screens more than one device's series shows, and the steps to them.
extension AppStoreScreenshotTests {
    /// Rename with Suggestions on the camera's photo among the summer's photos, named by
    /// the day they were taken.
    @MainActor
    func keepRenameWithSuggestions(_ name: String, in app: XCUIApplication, language: Language) {
        if Device.current.isCompact {
            showLocations(in: app, language: language)
        } else {
            showSidebar(in: app)
        }
        sidebar(of: app).staticTexts[language.photos].firstMatch.tap()
        let summer = row(language.summer, in: app)
        XCTAssertTrue(summer.waitForExistence(timeout: Self.timeout))
        summer.tap()
        XCTAssertTrue(row(Self.camera, in: app).waitForExistence(timeout: Self.timeout))
        perform(
            language.title("Rename with Suggestions…"), on: Self.camera, in: app,
            language: language)
        XCTAssertTrue(
            app.buttons["suggestion-0"].firstMatch.waitForExistence(timeout: Self.timeout),
            "a suggestion")
        keep(name, of: language)
    }

    /// New Folders from Template, the demo's template chosen, from Archive's Folder Structure.
    @MainActor
    func keepNewFoldersFromTemplate(_ name: String, in app: XCUIApplication, language: Language) {
        perform(
            language.title("Folder Structure"), on: language.archive, in: app, language: language)
        let fromTemplate = app.buttons[language.title("New Folders from Template")].firstMatch
        XCTAssertTrue(fromTemplate.waitForExistence(timeout: Self.timeout))
        fromTemplate.tap()
        let template = app.buttons[language.template].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: Self.timeout), "the demo's template")
        template.tap()
        XCTAssertTrue(
            app.buttons[language.title("Create Folders")].firstMatch.waitForExistence(
                timeout: Self.timeout))
        keep(name, of: language)
    }

    /// Two files selected and the Actions menu open.
    @MainActor
    func keepActions(_ name: String, in app: XCUIApplication, language: Language) {
        startSelecting(in: app, language: language)
        row(language.nearTop, in: app).tap()
        row(language.budget, in: app).tap()
        actionsButton(in: app, language: language).tap()
        XCTAssertTrue(
            app.buttons[language.title("Copy")].firstMatch.waitForExistence(
                timeout: Self.timeout), "the Actions menu")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "no keyboard with the menu")
        keep(name, of: language)
    }

    /// Performs a row's command through Select and the Actions menu; selecting goes on
    /// until the caller ends it.
    @MainActor
    func perform(
        _ command: String, on name: String, in app: XCUIApplication, language: Language
    ) {
        startSelecting(in: app, language: language)
        let item = row(name, in: app)
        XCTAssertTrue(item.waitForExistence(timeout: Self.timeout))
        item.tap()
        actionsButton(in: app, language: language).tap()
        // Copy has two Dutch titles, the app's and the shared commands'.
        let titles = command == "Kopieer" ? [command, "Kopiëren"] : [command]
        let entry = app.buttons.matching(NSPredicate(format: "label IN %@", titles)).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: Self.timeout), "\(command) in Actions")
        entry.tap()
    }

    /// Select, from the folder's one menu where the folder shows as on the iPhone.
    @MainActor
    private func startSelecting(in app: XCUIApplication, language: Language) {
        if Device.current.isCompact {
            app.buttons["moreMenu"].firstMatch.tap()
            app.buttons[language.title("Select")].firstMatch.tap()
        } else {
            toolbarButton(language.title("Select"), in: app).tap()
        }
    }

    @MainActor
    private func actionsButton(in app: XCUIApplication, language: Language) -> XCUIElement {
        let title = language.title("Actions")
        return Device.current.isCompact
            ? app.toolbars.buttons[title].firstMatch : toolbarButton(title, in: app)
    }

    /// Goes back from the folder to the locations, where the folder shows as on the iPhone.
    @MainActor
    func showLocations(in app: XCUIApplication, language: Language) {
        // On iOS 27 the system puts the bar's buttons in a strip of their own.
        let back = app.buttons["BackButton"].firstMatch
        if back.exists {
            back.tap()
        } else {
            app.navigationBars[language.documents].buttons.firstMatch.tap()
        }
        XCTAssertTrue(
            sidebar(of: app).staticTexts[language.photos].waitForExistence(
                timeout: Self.timeout), "the locations")
    }

    /// Shows the sidebar beside the folder when it is hidden, as on the Duo's inner display.
    @MainActor
    func showSidebar(in app: XCUIApplication) {
        let locations = sidebar(of: app)
        if isShown(locations) { return }
        // The system's button: named ToggleSidebar on iOS 18, only labelled on 27.
        let toggle = app.buttons.matching(
            NSPredicate(
                format: "identifier == 'ToggleSidebar' OR label IN %@",
                ["Show Sidebar", "Toon navigatiekolom", "Seitenleiste einblenden"])
        ).firstMatch
        XCTAssertTrue(
            toggle.waitForExistence(timeout: Self.timeout),
            "the sidebar's button among \(app.buttons.debugDescription)")
        toggle.tap()
        XCTAssertTrue(app.eventually { self.isShown(locations) }, "the sidebar")
    }

    /// Whether `element` is on the screen: on the Duo's inner display no element reports
    /// itself hittable, so its frame decides.
    @MainActor
    func isShown(_ element: XCUIElement) -> Bool {
        element.exists && element.frame.width > 1 && element.frame.maxX > 1
    }

    /// A button of the folder's toolbar, from its overflow menu where the toolbar has no room.
    @MainActor
    func toolbarButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: Self.timeout / 2) { return button }
        app.buttons["OverflowBarButtonItem"].firstMatch.tap()
        XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "\(label) in the overflow")
        return button
    }
}
