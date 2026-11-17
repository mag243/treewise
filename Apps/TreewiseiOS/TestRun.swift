import Foundation

/// A UI test's run of the app (ADR 0114), in Debug builds only: its bookmarks and settings
/// apart from the real ones, and a fixture of folders to add, as the test runner cannot make
/// folders the app may read.
/// - `-TreewiseTestState <name>`: the run's state, found again by a relaunch with that name.
/// - `-TreewiseTestFixture YES`: the folders `Documents` and `Work`, added when none are;
///   `Projects` holds a second `Budget.txt`, so a drop there asks about the name.
/// - `-TreewiseTestDemo YES`: instead, the App Store screenshots' folders (`DemoTree`).
/// - `-TreewiseTestRemove <folder>`: removes a fixture folder before the locations are read.
struct TestRun {
    private static let stateArgument = "TreewiseTestState"
    private static let fixtureArgument = "TreewiseTestFixture"
    private static let removeArgument = "TreewiseTestRemove"
    private static let demoArgument = "TreewiseTestDemo"
    /// The fixture's folders and their files.
    private static let fixture: [String: [String]] = [
        "Documents": ["Notes.md", "Budget.txt", "Projects/", "Projects/Budget.txt"],
        "Work": ["Report.txt"],
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

    /// Where the run keeps its bookmarks.
    var bookmarksFile: URL { folder.appendingPathComponent("Locations.json") }

    /// The fixture's folders to add, made if they are missing, when the launch asks for them.
    func fixtureFolders() throws -> [URL] {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: Self.demoArgument) {
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
                } else if !manager.fileExists(atPath: url.path) {
                    try Data("\(entry)\n".utf8).write(to: url)
                }
            }
            folders.append(location)
        }
        return folders
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
