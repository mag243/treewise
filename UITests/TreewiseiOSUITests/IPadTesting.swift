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
        QuiescenceShortcut.installIfAsked()
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

    /// Drags a finger across the whole of `element` from right to left: a full swipe, which
    /// performs a row's first swipe action at once on iOS 27 and shows its buttons on iOS 18.
    /// XCUITest's own swipe finds no visible frame for the sidebar's rows on iOS 18.
    @MainActor
    func swipeLeft(_ element: XCUIElement) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    func sidebar(of app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["locations"].firstMatch
    }
}
