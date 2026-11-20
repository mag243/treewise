import XCTest

/// The UI review's walk through folder templates (ADR 0103): `tools/build.sh uireview
/// templates`. The bar in an empty year and with missing folders, and the sheets that make
/// and save a structure, with the add-on in its trial.
extension UIReviewTests {
    @MainActor
    func testTemplates() throws {
        try eachAppearance(templates)
    }

    @MainActor
    private func templates(appearance: String?) throws {
        let app = try launch(appearance: appearance)
        startTrials(in: app)
        let window = app.windows.firstMatch
        app.go(to: "Administration/2028", timeout: Self.timeout)
        let bar = window.buttons["templateBarCreate"]
        XCTAssertTrue(bar.waitForExistence(timeout: Self.timeout), "an empty year offers a bar")
        review(window, as: "templates-bar-empty", appearance: appearance)
        press(bar)
        reviewSheet(of: window, as: "templates-sheet-year", appearance: appearance)
        app.go(to: "../2027", timeout: Self.timeout)
        XCTAssertTrue(bar.waitForExistence(timeout: Self.timeout), "a year lacking folders too")
        review(window, as: "templates-bar-missing", appearance: appearance)
        press(bar)
        reviewSheet(of: window, as: "templates-sheet-missing", appearance: appearance)
        app.typeKey(.upArrow, modifierFlags: .command)
        XCTAssertTrue(
            app.windows(titled: "Administration").firstMatch.waitForExistence(
                timeout: Self.timeout), "the window shows Administration")
        let year = window.tables.staticTexts["2026"]
        XCTAssertTrue(year.waitForExistence(timeout: Self.timeout))
        press(year, in: window.scrollViews.firstMatch, .rightClick)
        press(window.tables.menus.menuItems["Save Folder Structure as Template…"])
        reviewSheet(of: window, as: "templates-sheet-save", appearance: appearance)
        try renameInAllYears(in: app, appearance: appearance)
        try lookalike(in: app, appearance: appearance)
    }

    /// The bar asking about a missing folder nearly named as one there (ADR 0139):
    /// `Insurance` in 2026 and `Insurrance` in 2027, made last so the screens before keep
    /// their folders.
    @MainActor
    private func lookalike(in app: XCUIApplication, appearance: String?) throws {
        let administration = try XCTUnwrap(root).appendingPathComponent("Administration")
        for path in ["2026/Insurance", "2027/Insurrance"] {
            try FileManager.default.createDirectory(
                at: administration.appendingPathComponent(path),
                withIntermediateDirectories: true)
        }
        let window = app.windows.firstMatch
        app.go(to: "../2027", timeout: Self.timeout)
        let ask = window.buttons["templateBarAddAnyway"]
        XCTAssertTrue(ask.waitForExistence(timeout: Self.timeout), "the bar asks about the two")
        settleScreen()
        review(window, as: "templates-bar-lookalike", appearance: appearance)
    }

    /// Rename in All Years… on 2026's Receipts (ADR 0139): as it opens, with a name that
    /// 2027 has beside its Receipts, and with a long name.
    @MainActor
    private func renameInAllYears(in app: XCUIApplication, appearance: String?) throws {
        let window = app.windows.firstMatch
        app.go(to: "2026", timeout: Self.timeout)
        let receipts = window.tables.staticTexts["Receipts"]
        XCTAssertTrue(receipts.waitForExistence(timeout: Self.timeout))
        press(receipts, in: window.scrollViews.firstMatch, .rightClick)
        press(window.tables.menus.menuItems["Rename in All Years…"])
        let sheet = window.sheets.firstMatch
        let name = sheet.textFields["renameInAllYearsName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.timeout), "the sheet opens")
        settleScreen()
        review(window, as: "templates-rename-years-open", appearance: appearance)
        for (newName, shot) in [
            ("Bills", "templates-rename-years-beside"),
            (
                "Receipts and bills of the household kept for the yearly tax return",
                "templates-rename-years-long"
            ),
        ] {
            name.typeKey("a", modifierFlags: .command)
            name.typeText(newName)
            settleScreen()
            review(window, as: shot, appearance: appearance)
        }
        press(sheet.buttons["Cancel"])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: Self.timeout), "Cancel closes it")
    }

    /// Reviews the sheet that opened on `window`, then cancels it.
    @MainActor
    private func reviewSheet(of window: XCUIElement, as name: String, appearance: String?) {
        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout), "the sheet opens")
        settleScreen()
        review(window, as: name, appearance: appearance)
        press(sheet.buttons["Cancel"])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: Self.timeout), "Cancel closes it")
    }
}
