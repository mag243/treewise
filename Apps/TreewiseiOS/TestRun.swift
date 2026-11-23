import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A UI test's run of the app (ADR 0114), in Debug builds only: its bookmarks and settings
/// apart from the real ones, and a fixture of folders to add, as the test runner cannot make
/// folders the app may read.
/// - `-TreewiseTestState <name>`: the run's state, found again by a relaunch with that name.
/// - `-TreewiseTestFixture YES`: the folders `Documents` and `Work`, added when none are;
///   `Projects` holds a second `Budget.txt`, so a drop there asks about the name; `Photos`
///   holds three photos named by their date, the least a pattern is recognized from, and
///   `IMG_0042.jpg`, whose date is only in the
///   photo, for name proposals from a recognized and a typed pattern; and the template
///   `Household Year`, for Settings' Templates tab (ADR 0143).
/// - `-TreewiseTestDemo YES`: instead, the App Store screenshots' folders, template and
///   favorites (`DemoTree`).
/// - `-TreewiseTestRemove <folder>`: removes a fixture folder before the locations are read.
/// - `-TreewiseTestAppearance dark`: the app in dark mode, for the UI review's dark screens,
///   as the simulator does not pass a change of the device's appearance on to the app.
struct TestRun {
    private static let stateArgument = "TreewiseTestState"
    private static let fixtureArgument = "TreewiseTestFixture"
    private static let removeArgument = "TreewiseTestRemove"
    private static let demoArgument = "TreewiseTestDemo"
    private static let appearanceArgument = "TreewiseTestAppearance"
    private static let recentTargetArgument = "TreewiseTestRecentTarget"

    /// Whether the run asks for dark mode; always false in a Release build.
    static var isDark: Bool {
        #if DEBUG
            UserDefaults.standard.string(forKey: appearanceArgument) == "dark"
        #else
            false
        #endif
    }
    /// The fixture's folders and their files.
    private static let fixture: [String: [String]] = [
        "Documents": [
            "Notes.md", "Budget.txt", "Projects/", "Projects/Budget.txt", "Archive/",
        ],
        "Work": [
            "Report.txt", "Photos/", "Photos/2025-03-13 Harbour.jpg", "Photos/2025-03-14 Beach.jpg",
            "Photos/2025-03-15 Park.jpg", "Photos/IMG_0042.jpg",
        ],
    ]
    /// When each of the fixture's photos was taken, as the camera writes it in the photo.
    private static let captured = [
        "2025-03-13 Harbour.jpg": "2025:03:13 08:30:00",
        "2025-03-14 Beach.jpg": "2025:03:14 10:15:00", "2025-03-15 Park.jpg": "2025:03:15 16:40:00",
        "IMG_0042.jpg": "2025:03:16 09:05:00",
    ]

    /// The folder that holds the run's bookmarks and fixture.
    let folder: URL
    /// The run's settings, apart from the real ones.
    let defaults: UserDefaults

    /// The run the launch asks for, or `nil` for a normal launch and in a Release build.
    static var current: TestRun? {
        #if DEBUG
            guard let name = UserDefaults.standard.string(forKey: stateArgument),
                let defaults = UserDefaults(suiteName: "me.m-domain.treewise.uitests.\(name)")
            else { return nil }
            let folder = URL.temporaryDirectory.appendingPathComponent("UITests/\(name)")
            return TestRun(folder: folder, defaults: defaults)
        #else
            return nil
        #endif
    }

    /// The folders Favorites shows from the start: the demo's, when the launch asks for it.
    func fixtureFavorites() -> [URL] {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: Self.demoArgument) {
                return DemoTree.favorites(in: folder)
            }
        #endif
        return []
    }

    /// The folders Move to… shows among the recent targets from the start (ADR 0147): the
    /// demo's, or the one the launch names by its path in the run's folder, for a screen
    /// that shows the sheet without moving a file first.
    func fixtureRecentTargets() -> [URL] {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: Self.demoArgument) {
                return DemoTree.recentTargets(in: folder)
            }
        #endif
        guard let path = UserDefaults.standard.string(forKey: Self.recentTargetArgument)
        else { return [] }
        return [folder.appendingPathComponent(path)]
    }

    /// Where the run keeps its bookmarks.
    var bookmarksFile: URL { folder.appendingPathComponent("Locations.json") }

    /// The fixture's folders to add, made if they are missing, when the launch asks for them.
    func fixtureFolders() throws -> [URL] {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: Self.demoArgument) {
                try DemoTree.seedTemplate(in: templatesFolder)
                return try DemoTree.make(in: folder)
            }
        #endif
        guard UserDefaults.standard.bool(forKey: Self.fixtureArgument) else { return [] }
        let manager = FileManager.default
        var folders: [URL] = []
        for (name, entries) in Self.fixture.sorted(by: { $0.key < $1.key }) {
            let location = folder.appendingPathComponent(name)
            try manager.createDirectory(at: location, withIntermediateDirectories: true)
            for entry in entries {
                let url = location.appendingPathComponent(entry)
                if entry.hasSuffix("/") {
                    try manager.createDirectory(at: url, withIntermediateDirectories: true)
                } else if manager.fileExists(atPath: url.path) {
                    continue
                } else if let date = Self.captured[url.lastPathComponent] {
                    try Self.writePhoto(to: url, captured: date)
                } else {
                    try Data("\(entry)\n".utf8).write(to: url)
                }
            }
            folders.append(location)
        }
        try seedTemplate()
        return folders
    }

    /// A small grey photo with the date it was taken in its EXIF data.
    private static func writePhoto(to url: URL, captured: String) throws {
        let side = 8
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return }
        let exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: captured]
        CGImageDestinationAddImage(
            destination, image, [kCGImagePropertyExifDictionary: exif] as CFDictionary)
        CGImageDestinationFinalize(destination)
    }

    /// Where the run keeps its templates.
    private var templatesFolder: URL {
        folder.appendingPathComponent("Settings/Templates", isDirectory: true)
    }

    /// The fixture's template, kept where the run's templates are, unless it is there.
    private func seedTemplate() throws {
        let templates = templatesFolder
        let file = templates.appendingPathComponent("household.json")
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.createDirectory(at: templates, withIntermediateDirectories: true)
        let json = """
            {"format": 1, "id": "household", "name": "Household Year", "root": {"name": "{year}",
              "folders": [{"name": "Tax", "folders": [{"name": "Appeals"}]}, {"name": "Receipts"}]}}
            """
        try Data(json.utf8).write(to: file)
    }

    /// Removes the fixture folder the launch names, as a drive that is not attached.
    func removeAskedFolder() throws {
        guard let name = UserDefaults.standard.string(forKey: Self.removeArgument) else { return }
        let url = folder.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
