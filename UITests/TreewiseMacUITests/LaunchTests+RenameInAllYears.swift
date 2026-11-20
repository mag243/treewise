import XCTest

/// Rename in All Years…: a folder inside a year's folder renamed in every year from its
/// context menu, in the open build, and one Undo for all of it (ADR 0139).
extension LaunchTests {
    private static let years = ["2024", "2025"]
    private static let oldName = "Belastingsdienst"
    private static let newName = "Belastingdienst"

    /// `2024` and `2025` in the root, each with the misspelled folder.
    private func makeYearFolders() throws {
        let root = try XCTUnwrap(root)
        for year in Self.years {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent("\(year)/\(Self.oldName)"),
                withIntermediateDirectories: true)
        }
    }

    private func isFolder(_ path: String) throws -> Bool {
        let root = try XCTUnwrap(root)
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(
            atPath: root.appendingPathComponent(path).path, isDirectory: &isFolder)
            && isFolder.boolValue
    }

    @MainActor
    func testRenameInAllYearsRenamesEveryYearAndUndoesAsOne() throws {
        try makeYearFolders()
        let app = try launchApp()
        let window = app.windows.firstMatch
        let year = window.tables.staticTexts["2025"]
        XCTAssertTrue(year.appeared(timeout: Self.launchTimeout))
        year.doubleClick()
        let folder = window.tables.staticTexts[Self.oldName]
        XCTAssertTrue(folder.appeared(timeout: Self.launchTimeout))
        folder.rightClick()
        let item = window.tables.menus.menuItems["Rename in All Years…"]
        XCTAssertTrue(item.appeared(timeout: Self.launchTimeout), "the context menu offers it")
        item.click()

        let sheet = window.sheets.firstMatch
        let name = sheet.textFields["renameInAllYearsName"]
        XCTAssertTrue(name.appeared(timeout: Self.launchTimeout), "the sheet shows")
        XCTAssertEqual(name.value as? String, Self.oldName, "the name starts from its own")
        XCTAssertTrue(
            app.eventually { (name.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "the name is ready to type over")
        name.typeKey("a", modifierFlags: .command)
        name.typeText(Self.newName)
        let rename = sheet.buttons["renameInAllYearsRename"]
        XCTAssertEqual(rename.title, "Rename 2 Folders", "it names how many it renames")
        rename.click()

        XCTAssertTrue(
            window.staticTexts["Renamed 2 folders."].appeared(timeout: Self.launchTimeout),
            "the status bar says what was renamed")
        for year in Self.years {
            XCTAssertTrue(try isFolder("\(year)/\(Self.newName)"), "\(year) has the new name")
        }

        app.menuBarItems["Edit"].menuItems["Undo Rename in All Years"].click()
        let undone = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in
                (try? Self.years.allSatisfy { try self?.isFolder("\($0)/\(Self.oldName)") == true })
                    == true
            }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [undone], timeout: Self.launchTimeout), .completed,
            "one Undo gives every year its old name back")
    }
}
