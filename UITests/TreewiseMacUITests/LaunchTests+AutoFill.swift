import AppKit
import XCTest

/// Typing a name starts no AutoFill process that could take the keyboard (ADR 0085).
extension LaunchTests {
    /// The process macOS starts to offer AutoFill in a field of Treewise.
    private static let autoFillHelper = "com.apple.SafariPlatformSupport.Helper"

    @MainActor
    func testRenamingStartsNoAutoFill() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        let notes = window.tables.staticTexts["Notes.md"]
        XCTAssertTrue(notes.appeared(timeout: Self.launchTimeout))
        notes.click()
        app.typeKey(.return, modifierFlags: [])
        let field = window.tables.textFields.firstMatch
        XCTAssertTrue(field.appeared(timeout: Self.launchTimeout), "renaming starts")
        field.typeText("Renamed\r")
        XCTAssertTrue(
            window.tables.staticTexts["Renamed.md"].appeared(timeout: Self.launchTimeout),
            "the name typed is the file's name")

        let autoFill = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == Self.autoFillHelper
                && ($0.localizedName ?? "").hasSuffix("(Treewise)")
        }
        XCTAssertTrue(autoFill.isEmpty, "no AutoFill process for Treewise runs")
    }
}
