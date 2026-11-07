import XCTest

/// Applying the overview's names renames the files, and Undo Rename gives the old names
/// back (PLAN.md M7, acceptance).
extension LaunchTests {
    @MainActor
    func testApplyingRenamesTheFileAndUndoGivesItsNameBack() throws {
        let folder = try makeHolidayFolder()
        let app = try launchApp()
        let review = try openReview(of: Self.oddName, in: app)
        usePattern("Trip {seq}", in: review)
        let proposal = review.textFields.matching(
            NSPredicate(format: "value BEGINSWITH 'Trip '")
        ).firstMatch
        XCTAssertTrue(proposal.waitForExistence(timeout: Self.launchTimeout), "a name is proposed")
        let proposed = try XCTUnwrap(proposal.value as? String)

        review.buttons["Approve All"].click()
        let rename = review.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rename 1'"))
            .firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: Self.launchTimeout), "one is approved")
        rename.click()
        let old = folder.appendingPathComponent(Self.oddName).path
        let new = folder.appendingPathComponent(proposed).path
        XCTAssertTrue(
            app.eventually { FileManager.default.fileExists(atPath: new) }, "the file is renamed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old))

        let undo = app.buttons["Undo Rename"]
        XCTAssertTrue(undo.waitForExistence(timeout: Self.launchTimeout), "the result shows")
        undo.click()
        XCTAssertTrue(
            app.eventually { FileManager.default.fileExists(atPath: old) }, "its name is back")
        XCTAssertFalse(FileManager.default.fileExists(atPath: new))
    }
}
