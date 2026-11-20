import XCTest

/// The iPhone's UI review (ADR 0115, 0132): its screens walked as the iPad's are, on the
/// pinned iPhone. Run by `tools/build.sh iosreview`, which makes one report with the iPads';
/// `iosuitest` skips this class. A finding does not fail the walk.
final class IPhoneReviewTests: XCTestCase {
    private static let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Screens

    @MainActor
    func testStart() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString, fixture: false)
            XCTAssertTrue(
                app.buttons["Add Location"].firstMatch.waitForExistence(timeout: Self.timeout))
            review(app, as: "start", variant: variant)
            app.terminate()
        }
    }

    /// A folder, its menu, selecting, a folder below a location's top and the locations.
    @MainActor
    func testBrowser() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            review(app, as: "folder", variant: variant)

            app.buttons["moreMenu"].firstMatch.tap()
            let select = app.buttons["Select"].firstMatch
            XCTAssertTrue(select.waitForExistence(timeout: Self.timeout), "the menu")
            review(app, as: "more-menu", variant: variant)
            select.tap()
            row("Notes.md", in: app).tap()
            review(app, as: "selecting", variant: variant)
            app.toolbars.buttons["Copy"].firstMatch.tap()
            app.buttons["Done"].firstMatch.tap()
            let emptyClipboard = app.toolbars.buttons["emptyClipboard"].firstMatch
            XCTAssertTrue(emptyClipboard.waitForExistence(timeout: Self.timeout))
            review(app, as: "paste-bar", variant: variant)
            emptyClipboard.tap()

            row("Projects", in: app).tap()
            let up = app.buttons["enclosingFolder"].firstMatch
            XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
            review(app, as: "subfolder", variant: variant)
            up.tap()

            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            app.navigationBars["Documents"].buttons.firstMatch.tap()
            XCTAssertTrue(
                sidebar(of: app).staticTexts["Work"].waitForExistence(timeout: Self.timeout))
            review(app, as: "locations", variant: variant)
            app.terminate()
        }
    }

    /// The rename sheet with its proposals and the name overview (ADR 0129, 0130).
    @MainActor
    func testNames() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

            perform("Rename with Suggestions…", on: "Notes.md", in: app)
            XCTAssertTrue(app.buttons["suggestion-0"].waitForExistence(timeout: Self.timeout))
            review(app, as: "rename-suggestions", variant: variant)
            app.navigationBars["Rename"].buttons["Cancel"].tap()
            app.buttons["Done"].firstMatch.tap()

            perform("Suggest Names…", on: "Notes.md", in: app)
            let proposal = app.textFields["proposal-Notes.md"].firstMatch
            XCTAssertTrue(proposal.waitForExistence(timeout: Self.timeout))
            review(app, as: "name-overview", variant: variant)
            app.buttons["About Notes.md"].firstMatch.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)["nameDetails"].firstMatch.waitForExistence(
                    timeout: Self.timeout))
            review(app, as: "name-details", variant: variant)
            app.terminate()
        }
    }

    /// The folder templates (ADR 0143, M6e): Save as Template… and New Folders from Template
    /// from a folder's Folder Structure ▸, Rename in All Years… in the year's folder made, and
    /// Settings' Templates tab with a template's tree and a folder's name.
    @MainActor
    func testTemplates() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Archive", in: app).waitForExistence(timeout: Self.timeout))
            perform("Folder Structure", on: "Archive", in: app)
            app.buttons["Save as Template…"].firstMatch.tap()
            let save = app.navigationBars["Save as Template"]
            XCTAssertTrue(save.waitForExistence(timeout: Self.timeout))
            review(app, as: "save-template", variant: variant)
            save.buttons["Cancel"].tap()

            app.toolbars.buttons["Actions"].firstMatch.tap()
            app.buttons["Folder Structure"].firstMatch.tap()
            app.buttons["New Folders from Template"].firstMatch.tap()
            app.buttons["Household Year"].firstMatch.tap()
            let make = app.buttons["Create Folders"].firstMatch
            XCTAssertTrue(make.waitForExistence(timeout: Self.timeout))
            review(app, as: "new-folders", variant: variant)
            make.tap()
            app.buttons["Done"].firstMatch.tap()

            reviewRenameInAllYears(in: app, variant: variant)
            reviewTemplateSettings(in: app, variant: variant)
            app.terminate()
        }
    }

    /// Rename in All Years… on Tax in the year's folder made in Archive, a name typed.
    @MainActor
    private func reviewRenameInAllYears(in app: XCUIApplication, variant: String) {
        row("Archive", in: app).tap()
        let year = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]{4}$'"))
            .firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout))
        year.tap()
        perform("Rename in All Years…", on: "Tax", in: app)
        let name = app.textFields["renameInAllYearsName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout))
        name.tap()
        // Return puts the keyboard away, which would cover the years in landscape.
        name.typeText("es\n")
        review(app, as: "rename-in-all-years", variant: variant)
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()
    }

    /// Settings' Templates tab, the fixture's template and one of its folders' names.
    @MainActor
    private func reviewTemplateSettings(in app: XCUIApplication, variant: String) {
        // Up from the year's folder to Archive and Documents, then back to the locations'
        // screen, where the gear is.
        let up = app.buttons["enclosingFolder"].firstMatch
        up.tap()
        XCTAssertTrue(app.navigationBars["Archive"].waitForExistence(timeout: Self.timeout))
        up.tap()
        XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
        app.navigationBars["Documents"].buttons.firstMatch.tap()
        let gear = app.buttons["settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.timeout))
        gear.tap()
        app.buttons["Templates"].firstMatch.tap()
        let template = app.staticTexts["Household Year"].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: Self.timeout))
        review(app, as: "templates", variant: variant)
        template.tap()
        let receipts = app.buttons["Receipts"].firstMatch
        XCTAssertTrue(receipts.waitForExistence(timeout: Self.timeout))
        review(app, as: "template-tree", variant: variant)
        receipts.tap()
        XCTAssertTrue(
            app.textFields["templateFolderName"].waitForExistence(timeout: Self.timeout))
        review(app, as: "template-folder-name", variant: variant)
    }

    /// Move to… with a recent folder above the favorites and the locations (ADR 0132).
    @MainActor
    func testMoveTo() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            row("Projects", in: app).tap()
            let up = app.buttons["enclosingFolder"].firstMatch
            XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
            up.tap()
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))

            perform("Move to…", on: "Notes.md", in: app)
            XCTAssertTrue(
                app.buttons["recent-Projects"].firstMatch.waitForExistence(timeout: Self.timeout))
            review(app, as: "move-to", variant: variant)
            app.terminate()
        }
    }

    /// Settings and its saved patterns, from the locations' screen (ADR 0130).
    @MainActor
    func testSettings() throws {
        try eachReviewVariant { variant in
            let app = launch(state: UUID().uuidString)
            XCTAssertTrue(row("Notes.md", in: app).waitForExistence(timeout: Self.timeout))
            app.navigationBars["Documents"].buttons.firstMatch.tap()
            app.buttons["settings"].firstMatch.tap()
            let saved = app.buttons["savedPatterns"].firstMatch
            XCTAssertTrue(saved.waitForExistence(timeout: Self.timeout))
            review(app, as: "settings", variant: variant)
            saved.tap()
            review(app, as: "saved-patterns", variant: variant)
            app.terminate()
        }
    }

    // MARK: - Doing

    /// Performs a row's command through the folder's menu, Select and the Actions menu
    /// below; selecting goes on until the caller ends it.
    @MainActor
    private func perform(_ command: String, on name: String, in app: XCUIApplication) {
        app.buttons["moreMenu"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()
        row(name, in: app).tap()
        app.toolbars.buttons["Actions"].firstMatch.tap()
        let item = app.buttons[command].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.timeout), "\(command) in Actions")
        item.tap()
    }
}
