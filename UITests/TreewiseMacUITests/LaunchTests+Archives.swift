import XCTest

/// Extracting and compressing on a fixture (ADR 0074).
extension LaunchTests {
    /// A zip that holds `inside.txt`, stored without compression.
    private static let archive =
        "UEsDBBQAAAAAAGV4aV2m38+IEAAAABAAAAAKAAAAaW5zaWRlLnR4dGZyb20gdGhlIGFyY2hpdmVQSwECFAMUAAAAAABleGldpt/PiBAAAAAQAAAACgAAAAAAAAAAAAAAgAEAAAAAaW5zaWRlLnR4dFBLBQYAAAAAAQABADgAAAA4AAAAAAA="

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
}
