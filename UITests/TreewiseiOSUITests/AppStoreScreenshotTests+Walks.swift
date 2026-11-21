import XCTest

/// Each device's series of screens (ADR 0145), in the order the App Store shows them.
extension AppStoreScreenshotTests {
    /// The 13-inch iPad, in landscape but for the last: the folder, a drag with a name
    /// conflict, the context menu, Rename with Suggestions, New Folders from Template and
    /// the folder in portrait.
    @MainActor
    func walkIPad(_ language: Language) {
        XCUIDevice.shared.orientation = .landscapeLeft
        var app = open(language)
        keep("01-folder", of: language)
        drag(row(language.budget, in: app), onto: row(language.archive, in: app))
        XCTAssertTrue(
            app.switches.firstMatch.waitForExistence(timeout: Self.timeout), "the conflict sheet")
        keep("02-conflict", of: language)
        app.terminate()

        app = open(language)
        row(language.budget, in: app).press(forDuration: Self.longPress)
        keep("03-context-menu", of: language)
        app.terminate()

        app = open(language)
        keepRenameWithSuggestions("04-rename-suggestions", in: app, language: language)
        app.terminate()

        app = open(language)
        keepNewFoldersFromTemplate("05-new-folders", in: app, language: language)
        app.terminate()

        XCUIDevice.shared.orientation = .portrait
        app = open(language)
        keep("06-portrait", of: language)
        app.terminate()
    }

    /// The iPhone: the folder, the locations, selecting with Actions, Move to… with a recent
    /// folder, Rename with Suggestions and New Folders from Template.
    @MainActor
    func walkIPhone(_ language: Language) {
        XCUIDevice.shared.orientation = .portrait
        var app = open(language)
        keep("01-folder", of: language)
        showLocations(in: app, language: language)
        keep("02-locations", of: language)
        app.terminate()

        app = open(language)
        keepActions("03-actions", in: app, language: language)
        app.terminate()

        app = open(language)
        row(language.archive, in: app).tap()
        let up = app.buttons["enclosingFolder"].firstMatch
        XCTAssertTrue(up.waitForExistence(timeout: Self.timeout))
        up.tap()
        XCTAssertTrue(row(language.budget, in: app).waitForExistence(timeout: Self.timeout))
        perform(language.title("Move to…"), on: language.budget, in: app, language: language)
        XCTAssertTrue(
            app.buttons["recent-\(language.archive)"].firstMatch.waitForExistence(
                timeout: Self.timeout))
        keep("04-move-to", of: language)
        app.terminate()

        app = open(language)
        keepRenameWithSuggestions("05-rename-suggestions", in: app, language: language)
        app.terminate()

        app = open(language)
        keepNewFoldersFromTemplate("06-new-folders", in: app, language: language)
        app.terminate()
    }

    /// The iPhone Duo folded shut, its outer display as an iPhone: the folder, two files
    /// selected and Rename with Suggestions. No menu is shown open: on iOS 27.2 a menu there
    /// brings the keyboard up with it.
    @MainActor
    func walkDuoOuter(_ language: Language) {
        var app = open(language)
        keep("01-folder", of: language)
        startSelecting(in: app, language: language)
        row(language.nearTop, in: app).tap()
        row(language.budget, in: app).tap()
        keep("02-selecting", of: language)
        app.terminate()

        app = open(language)
        keepRenameWithSuggestions("03-rename-suggestions", in: app, language: language)
        app.terminate()
    }

    /// The iPhone Duo open, its inner display in landscape as an iPad: the sidebar beside the
    /// folder, New Folders from Template, and a name conflict from a paste, as a drag misses
    /// there.
    @MainActor
    func walkDuoInner(_ language: Language) {
        var app = open(language)
        showSidebar(in: app)
        keep("01-sidebar", of: language)
        app.terminate()

        app = open(language)
        keepNewFoldersFromTemplate("02-new-folders", in: app, language: language)
        app.terminate()

        app = open(language)
        perform(language.title("Copy"), on: language.budget, in: app, language: language)
        row(language.archive, in: app).tap()
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(
                    format:
                        "label BEGINSWITH 'Tax' OR label BEGINSWITH 'Belasting' OR label BEGINSWITH 'Steuer'"
                )
            ).firstMatch
                .waitForExistence(timeout: Self.timeout), "in Archive")
        toolbarButton(language.title("Paste"), in: app).tap()
        XCTAssertTrue(
            app.switches.firstMatch.waitForExistence(timeout: Self.timeout), "the conflict sheet")
        keep("03-conflict", of: language)
        app.terminate()
    }
}
