import XCTest

/// How long Suggest Names… takes on a folder of 100 files, from the menu until every file
/// has been read, through the modules' service as users run it (M7, speed targets). Runs
/// only from `tools/build.sh benchmark`, which reads the times from the result bundle; it
/// sets no limit.
final class BenchmarkTests: XCTestCase {
    private static let timeout: TimeInterval = 60
    private static let fileCount = 100
    /// The files whose names follow the folder's pattern; the rest get proposals.
    private static let fittingCount = 60
    private static let iterations = 5
    private static let folderName = "Holiday"

    private var root: URL?

    override func setUpWithError() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreewiseBenchmark-\(UUID().uuidString)", isDirectory: true)
        let holiday = folder.appendingPathComponent(Self.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: holiday, withIntermediateDirectories: true)
        for index in 0..<Self.fileCount {
            let day = index % 28 + 1
            let name =
                index < Self.fittingCount
                ? String(format: "2026.08.%02d Holiday - Place %d.txt", day, index)
                : "IMG_\(4000 + index).txt"
            try Data("photo".utf8).write(to: holiday.appendingPathComponent(name))
        }
        root = folder
    }

    override func tearDownWithError() throws {
        if let root { try FileManager.default.removeItem(at: root) }
    }

    @MainActor
    func testSuggestNamesOnAFolderOfAHundredFiles() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseRoot", try XCTUnwrap(root).path, "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        let folder = app.tables.staticTexts[Self.folderName]
        XCTAssertTrue(folder.waitForExistence(timeout: Self.timeout), "the folder shows")
        let options = XCTMeasureOptions()
        options.iterationCount = Self.iterations
        measure(metrics: [XCTClockMetric()], options: options) {
            folder.rightClick()
            app.tables.menus.menuItems["Suggest Names…"].click()
            let review = app.windows.matching(
                NSPredicate(format: "title BEGINSWITH 'Suggest Names'")
            ).firstMatch
            XCTAssertTrue(review.waitForExistence(timeout: Self.timeout), "the overview opens")
            let reading = review.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH 'Reading '")
            ).firstMatch
            XCTAssertTrue(reading.waitForNonExistence(timeout: Self.timeout), "every file is read")
            review.buttons["Cancel"].firstMatch.click()
            XCTAssertTrue(review.waitForNonExistence(timeout: Self.timeout), "it closes")
        }
    }
}
