import XCTest

/// A selected file whose name fits keeps it, and another name is typed from it (ADR 0138).
extension LaunchTests {
    @MainActor
    func testReturnOnAFittingNameEditsItFromItself() throws {
        _ = try makeHolidayFolder()
        let fitting = "2026.08.14 Holiday - Beach.heic"
        let app = try launchApp()
        let review = try openReview(of: fitting, in: app)
        review.outlines.staticTexts[fitting].firstMatch.click()
        app.typeKey(.return, modifierFlags: [])
        let name = review.outlines.textFields.firstMatch
        XCTAssertTrue(
            app.eventually { (name.value(forKey: "hasKeyboardFocus") as? Bool) == true },
            "Return edits a name that fits")
        XCTAssertEqual(name.value as? String, fitting, "the edit starts from the name it has")
    }
}
