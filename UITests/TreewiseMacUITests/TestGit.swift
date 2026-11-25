import XCTest

/// Runs git for a UI test, apart from the user's own settings, with a name to commit under.
enum TestGit {
    /// Runs git in `folder` and fails the test when it fails.
    static func run(_ arguments: [String], in folder: URL, allowingFailure: Bool = false) throws {
        let process = Process()
        process.executableURL = try executable()
        process.arguments =
            ["-C", folder.path, "-c", "user.name=Test", "-c", "user.email=test@example.com"]
            + arguments
        process.environment = ["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard !allowingFailure else { return }
        XCTAssertEqual(process.terminationStatus, 0, "git \(arguments.joined(separator: " "))")
    }

    /// The git of the Xcode that runs the test. The runner lives in the App Sandbox, where
    /// `/usr/bin/git`, which hands over through `xcrun`, refuses to run.
    private static func executable() throws -> URL {
        let framework = Bundle(for: XCTestCase.self).bundlePath
        let contents = try XCTUnwrap(
            framework.range(of: ".app/Contents/").map { framework[..<$0.upperBound] },
            "XCTest outside an Xcode: \(framework)")
        return URL(fileURLWithPath: contents + "Developer/usr/bin/git")
    }
}
