import XCTest

/// Ending a test's run of the app.
extension XCUIApplication {
    /// How long a quit with ⌘Q may take before XCTest stops the app itself.
    private static let quitTimeout: TimeInterval = 5

    /// Quits the app as a person does, with ⌘Q, which runs Treewise's own end and
    /// takes a quarter of a second where `terminate()` takes more than one. When the
    /// app stays, because a sheet or an alert asks something first, XCTest stops it.
    @MainActor
    func quit() {
        guard state != .notRunning else { return }
        typeKey("q", modifierFlags: .command)
        if !wait(for: .notRunning, timeout: Self.quitTimeout) { terminate() }
    }
}
