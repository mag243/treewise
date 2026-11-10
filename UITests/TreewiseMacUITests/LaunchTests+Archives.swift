import AppKit
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

    /// A file pasted into a zip lands in it, and undo takes it out again.
    @MainActor
    func testAFilePastedIntoAZipLandsAndUndoTakesItOut() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        let app = try launchApp()
        let window = app.windows.firstMatch
        let notes = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        notes.click()
        app.typeKey("c", modifierFlags: .command)
        window.tables.staticTexts["Photos.zip"].doubleClick()
        XCTAssertTrue(
            window.tables.staticTexts["inside.txt"].appeared(timeout: Self.launchTimeout))

        app.typeKey("v", modifierFlags: .command)

        XCTAssertTrue(
            window.tables.staticTexts["Notes.md"].appeared(timeout: Self.launchTimeout),
            "the file is in the zip")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(
            window.tables.staticTexts["Notes.md"].disappeared(timeout: Self.launchTimeout),
            "undo takes it out")
        XCTAssertTrue(window.tables.staticTexts["inside.txt"].exists, "the rest stays")
    }

    /// Drags a file out of a zip to Finder: a folder outside the boundary
    /// refuses it and leaves dragging working, a folder inside gets the file.
    @MainActor
    func testDraggingOutOfAZipToFinder() throws {
        let root = try XCTUnwrap(self.root)
        try XCTUnwrap(Data(base64Encoded: Self.archive))
            .write(to: root.appendingPathComponent("Photos.zip"))
        closeFinderWindowsOfThisTest()
        let allowed = root.appendingPathComponent("DropHere")
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: false)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("OutsideTreewise-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: outside) }
        let app = try launchApp()
        let window = app.windows.firstMatch
        let zip = window.tables.staticTexts["Photos.zip"]
        XCTAssertTrue(zip.appeared(timeout: Self.launchTimeout))
        zip.doubleClick()
        let inside = window.tables.staticTexts["inside.txt"]
        XCTAssertTrue(inside.appeared(timeout: Self.launchTimeout))
        let refused = outside.appendingPathComponent("inside.txt").path
        try drag(inside, in: app, to: outside)
        Thread.sleep(forTimeInterval: Self.settle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: refused), "outside: nothing lands")
        let alert = window.sheets.firstMatch
        XCTAssertTrue(alert.appeared(timeout: Self.launchTimeout), "the window tells why")
        alert.buttons["OK"].click()

        try drag(inside, in: app, to: allowed)

        let landed = allowed.appendingPathComponent("inside.txt").path
        let deadline = Date().addingTimeInterval(Self.launchTimeout)
        while !FileManager.default.fileExists(atPath: landed), Date() < deadline {
            Thread.sleep(forTimeInterval: Self.landingPoll)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: landed), "inside: the file lands")
        XCTAssertEqual(try String(contentsOfFile: landed, encoding: .utf8), "from the archive")
    }

    /// Opens `folder` in Finder, drags `element` to a part of that window that
    /// Treewise leaves free, and closes the window.
    @MainActor
    private func drag(_ element: XCUIElement, in app: XCUIApplication, to folder: URL) throws {
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        NSWorkspace.shared.open(folder)
        let finderWindow = finder.windows[folder.lastPathComponent]
        XCTAssertTrue(finderWindow.appeared(timeout: Self.launchTimeout), "Finder shows the folder")
        defer { closeFinderWindowsOfThisTest() }
        // Finder places each new window further down, under Treewise's.
        finder.activate()
        let grab = finderWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: Self.finderGrabHeight))
        // Only as far up as it takes, so that it stays on its own display.
        let finderTarget = finderWindow.frame
        let wanted = app.windows.firstMatch.frame.minY - finderTarget.height * 0.3 - Self.finderGap
        if finderTarget.minY > wanted {
            grab.click(
                forDuration: Self.dragHold,
                thenDragTo: grab.withOffset(CGVector(dx: 0, dy: wanted - finderTarget.minY)))
        }
        app.activate()
        let treewise = app.windows.firstMatch.frame
        let frame = finderWindow.frame
        let free = Self.finderDropPoints.first { point in
            !treewise.contains(
                CGPoint(
                    x: frame.minX + frame.width * point.dx,
                    y: frame.minY + frame.height * point.dy))
        }
        guard let point = free else { throw XCTSkip("Treewise covers Finder's whole list") }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click(
            forDuration: Self.dragHold,
            thenDragTo: finderWindow.coordinate(withNormalizedOffset: point),
            withVelocity: .slow, thenHoldForDuration: Self.dragHold)
    }

    /// Closes what this test opened in Finder, also after an earlier run:
    /// each window left open makes Finder place the next one further down.
    @MainActor
    private func closeFinderWindowsOfThisTest() {
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        let ours = finder.windows.matching(
            NSPredicate(format: "title BEGINSWITH 'OutsideTreewise-' OR title == 'DropHere'"))
        while ours.firstMatch.exists {
            finder.activate()
            // Activating raises Finder's last window, which need not be ours;
            // the Window menu raises the one with this title. It is found by
            // place, just before Help, as its title follows the Mac's language.
            let window = ours.firstMatch
            let items = finder.menuBars.firstMatch.menuBarItems
            let windowMenu = items.element(boundBy: items.count - 2)
            windowMenu.click()
            windowMenu.menuItems[window.title].click()
            window.buttons[XCUIIdentifierCloseWindow].click()
        }
    }

    /// Places in Finder's list of files, right of its sidebar and below its toolbar.
    private static var finderDropPoints: [CGVector] {
        stride(from: 0.3, through: 0.9, by: 0.05).flatMap { dy in
            stride(from: 0.35, through: 0.95, by: 0.1).map { dx in CGVector(dx: dx, dy: dy) }
        }
    }
    private static let settle: TimeInterval = 2
    private static let finderGrabHeight: CGFloat = 8
    private static let finderGap: CGFloat = 20

    private static let landingPoll: TimeInterval = 0.2
    private static let dragHold: TimeInterval = 0.6
}
