import XCTest

/// What the iPad's UI tests share (ADR 0114): a run in a state of its own, with the fixture's
/// folders `Documents` and `Work` added, and the elements they look for.
extension XCTestCase {
    /// Starts Treewise in the state `name`, with the fixture's folders unless `fixture` is
    /// false, after removing the fixture folder `removing`.
    @MainActor
    func launch(state name: String, fixture: Bool = true, removing: String? = nil)
        -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseTestState", name, "-TreewiseTestFixture", fixture ? "YES" : "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        if let removing { app.launchArguments += ["-TreewiseTestRemove", removing] }
        if UIReviewWalk.appearance == "dark" {
            app.launchArguments += ["-TreewiseTestAppearance", "dark"]
        }
        app.launch()
        return app
    }

    /// A name in the folder's table, which reports each name twice to the tests.
    @MainActor
    func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }

    @MainActor
    func sidebar(of app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["locations"].firstMatch
    }
}
