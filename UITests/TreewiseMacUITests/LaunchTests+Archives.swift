import XCTest

/// Extracting and compressing on a fixture (ADR 0074).
extension LaunchTests {
    /// A zip that holds `inside.txt`, stored without compression.
    private static let archive =
        "UEsDBBQAAAAAAGV4aV2m38+IEAAAABAAAAAKAAAAaW5zaWRlLnR4dGZyb20gdGhlIGFyY2hpdmVQSwECFAMUAAAAAABleGldpt/PiBAAAAAQAAAACgAAAAAAAAAAAAAAgAEAAAAAaW5zaWRlLnR4dFBLBQYAAAAAAQABADgAAAA4AAAAAAA="

    /// More files than any window shows at once in the icon view.
    private static let filesThatFillTheIconView = 120
    /// More files than any window shows at once in the list, and few enough:
    /// XCUITest reads every row each time it looks for an element, which on a
    /// runner takes longer than its wait for 120 rows.
    private static let filesThatFillTheList = 40

    @MainActor
    func testExtractAllMakesAFolderNamedAfterTheArchive() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let row = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        row.click()

        let extract = window.buttons["Extract All…"]
        XCTAssertTrue(extract.appeared(timeout: Self.launchTimeout))
        extract.click()
        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.appeared(timeout: Self.launchTimeout), "Treewise asks where to")
        sheet.buttons["Extract"].click()

        XCTAssertTrue(
            window.tables.staticTexts["Photos"].appeared(timeout: Self.launchTimeout),
            "the folder shows beside the archive")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Photos/inside.txt").path))
    }

    @MainActor
    func testCompressToZipPutsAnArchiveBesideTheItemAndStartsRenaming() throws {
        let root = try XCTUnwrap(self.root)
        let app = try launchApp()
        let window = app.windows.firstMatch
        let row = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        row.click()

        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["Compress to ZIP"].click()

        let name = window.tables.textFields.firstMatch
        XCTAssertTrue(name.appeared(timeout: Self.launchTimeout), "renaming starts on the archive")
        XCTAssertEqual(name.value as? String, "Notes.zip")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("Notes.zip").path))
    }

    /// Fills the root so that the archive of the folder `Zebra`, which sorts
    /// after every file, lands far below the folder itself.
    private func fillRootBelowAFolderToCompress(_ root: URL, files: Int) throws {
        let folder = root.appendingPathComponent("Zebra")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try Data("stripes".utf8).write(to: folder.appendingPathComponent("inside.txt"))
        for number in 0..<files {
            try Data().write(to: root.appendingPathComponent("a \(number).txt"))
        }
    }

    @MainActor
    func testCompressingInAFullFolderBringsTheArchiveIntoViewInTheList() throws {
        try fillRootBelowAFolderToCompress(
            try XCTUnwrap(self.root), files: Self.filesThatFillTheList)
        let app = try launchApp()
        let window = app.windows.firstMatch
        let row = window.tables.staticTexts["Zebra"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))
        row.click()

        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["Compress to ZIP"].click()

        let name = window.tables.textFields.firstMatch
        XCTAssertTrue(name.appeared(timeout: Self.launchTimeout), "renaming starts on the archive")
        XCTAssertEqual(name.value as? String, "Zebra.zip")
        // `isHittable` is false for a list's rename field, also for one in view.
        XCTAssertTrue(window.frame.contains(name.frame), "the archive is in view")
    }

    @MainActor
    func testCompressingInAFullFolderBringsTheArchiveIntoViewInTheIconView() throws {
        try fillRootBelowAFolderToCompress(
            try XCTUnwrap(self.root), files: Self.filesThatFillTheIconView)
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.tables.staticTexts["Zebra"].appeared(timeout: Self.launchTimeout))
        window.descendants(matching: .any)["as Icons"].firstMatch.click()
        let tile = window.collectionViews.staticTexts["Zebra"]
        XCTAssertTrue(tile.appeared(timeout: Self.launchTimeout))
        tile.click()

        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["Compress to ZIP"].click()

        let name = window.collectionViews.textFields.firstMatch
        XCTAssertTrue(name.appeared(timeout: Self.launchTimeout), "renaming starts on the archive")
        XCTAssertEqual(name.value as? String, "Zebra.zip")
        XCTAssertTrue(name.isHittable, "the archive is in view")
    }

    @MainActor
    func testAZipOpensAsAFolderAndAFileCopiesOutOfIt() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let row = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))

        row.doubleClick()

        let inside = window.tables.staticTexts["inside.txt"]
        XCTAssertTrue(inside.appeared(timeout: Self.launchTimeout), "the zip opens as a folder")
        inside.click()
        app.typeKey("c", modifierFlags: .command)
        app.typeKey("[", modifierFlags: .command)
        XCTAssertTrue(
            window.tables.staticTexts["Photos.zip"].appeared(timeout: Self.launchTimeout),
            "going back leaves the zip")
        app.typeKey("v", modifierFlags: .command)

        XCTAssertTrue(
            window.tables.staticTexts["inside.txt"].appeared(timeout: Self.launchTimeout),
            "the file lands beside the zip")
        XCTAssertEqual(
            try String(contentsOf: root.appendingPathComponent("inside.txt"), encoding: .utf8),
            "from the archive")
    }

    @MainActor
    func testOpeningAZipOpensTheSidebarDownToIt() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let row = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(row.appeared(timeout: Self.launchTimeout))

        row.doubleClick()

        XCTAssertTrue(
            window.outlines.staticTexts["Photos.zip"].appeared(timeout: Self.launchTimeout),
            "the sidebar shows the zip")
    }

    /// A drag out of a zip carries a promise that a drop within Treewise does
    /// not use; left open, it holds up quitting.
    @MainActor
    func testQuittingAfterDraggingOutOfAZipWithinTreewise() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let zip = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(zip.appeared(timeout: Self.launchTimeout))
        zip.doubleClick()
        let inside = window.tables.staticTexts["inside.txt"]
        XCTAssertTrue(inside.appeared(timeout: Self.launchTimeout))
        let target = window.outlines.staticTexts["Projects"].firstMatch
        XCTAssertTrue(target.appeared(timeout: Self.launchTimeout))

        let centre = CGVector(dx: 0.5, dy: 0.5)
        inside.coordinate(withNormalizedOffset: centre).click(
            forDuration: Self.dragHold,
            thenDragTo: target.coordinate(withNormalizedOffset: centre),
            withVelocity: .slow, thenHoldForDuration: Self.dragHold)

        let landed = root.appendingPathComponent("Projects/inside.txt").path
        let deadline = Date().addingTimeInterval(Self.launchTimeout)
        while !FileManager.default.fileExists(atPath: landed), Date() < deadline {
            Thread.sleep(forTimeInterval: Self.landingPoll)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: landed), "the file lands")
        assertQuitsPromptly(app)
    }

    @MainActor
    func testQuittingAfterADragOutOfAZipThatLandsNowhere() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let zip = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(zip.appeared(timeout: Self.launchTimeout))
        zip.doubleClick()
        let inside = window.tables.staticTexts["inside.txt"]
        XCTAssertTrue(inside.appeared(timeout: Self.launchTimeout))

        inside.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click(
            forDuration: Self.dragHold,
            thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.02)),
            withVelocity: .slow, thenHoldForDuration: Self.dragHold)

        assertQuitsPromptly(app)
    }

    /// A held-up quit shows in the time, as XCUITest waits for it while it
    /// sends the key and the app is gone by the time it looks.
    @MainActor
    private func assertQuitsPromptly(_ app: XCUIApplication) {
        let start = Date()
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.launchTimeout), "Treewise quits")
        XCTAssertLessThan(Date().timeIntervalSince(start), Self.launchTimeout, "without delay")
    }

    private static let landingPoll: TimeInterval = 0.2
    private static let dragHold: TimeInterval = 0.6
}
