import AppKit
import XCTest

/// The screenshots of the download page (ADR 0041): each test sets up a scene
/// on the sandbox volumes and keeps a screenshot of it. Run with
/// `tools/build.sh screenshots`, which passes the volumes in
/// `TREEWISE_SANDBOX`; `ci` skips this class.
final class ScreenshotTests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// The size of a window's content in every screenshot.
    private static let windowSize = "1280x800"
    /// How long a scene settles before its screenshot: thumbnails and the
    /// details pane's preview load in the background and offer nothing to
    /// wait for. A screenshot tests no behaviour, so a fixed pause is fine.
    private static let settle: TimeInterval = 2

    // Each scene in light and in dark, to choose from for the page.

    @MainActor func testMainWindowLight() throws { try mainWindow(dark: false) }
    @MainActor func testMainWindowDark() throws { try mainWindow(dark: true) }
    @MainActor func testIconViewLight() throws { try iconView(dark: false) }
    @MainActor func testIconViewDark() throws { try iconView(dark: true) }
    @MainActor func testTabsLight() throws { try tabs(dark: false) }
    @MainActor func testTabsDark() throws { try tabs(dark: true) }
    @MainActor func testTwoWindowsBesideLight() throws { try twoWindowsBeside(dark: false) }
    @MainActor func testTwoWindowsBesideDark() throws { try twoWindowsBeside(dark: true) }

    // MARK: - Scenes

    @MainActor
    private func iconView(dark: Bool) throws {
        let app = try launch(dark: dark)
        go(to: "Downloads", in: app)
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(
            app.collectionViews.staticTexts["Floor plan.pdf"].waitForExistence(
                timeout: Self.timeout))
        settleScene()
        keep(app.windows.firstMatch.screenshot(), as: name("02-icons", dark: dark))
    }

    @MainActor
    private func tabs(dark: Bool) throws {
        let app = try launch(dark: dark)
        go(to: "Projects", in: app)
        app.typeKey("t", modifierFlags: .command)
        go(to: "../Pictures", in: app)
        app.typeKey("t", modifierFlags: .command)
        go(to: "../Documents", in: app)
        XCTAssertTrue(
            app.tables.staticTexts["Budget 2026.xlsx"].waitForExistence(timeout: Self.timeout))
        settleScene()
        keep(app.windows.firstMatch.screenshot(), as: name("03-tabs", dark: dark))
    }

    @MainActor
    private func twoWindowsBeside(dark: Bool) throws {
        let app = try launch(dark: dark)
        go(to: "Documents", in: app)
        app.typeKey("n", modifierFlags: [.command, .option])
        XCTAssertTrue(app.windows.element(boundBy: 1).waitForExistence(timeout: Self.timeout))
        go(to: "../Projects", in: app)
        let first = app.windows.element(boundBy: 0)
        let second = app.windows.element(boundBy: 1)
        XCTAssertTrue(app.eventually { first.frame.intersection(second.frame).width <= 0 })
        // Only the screen beneath both windows, so the desktop and other apps
        // stay out; the windows are on the main display.
        settleScene()
        keep(
            try crop(XCUIScreen.main.screenshot(), to: first.frame.union(second.frame)),
            as: name("04-beside", dark: dark))
    }

    @MainActor
    private func mainWindow(dark: Bool) throws {
        let app = try launch(dark: dark)
        go(to: "Pictures", in: app)
        // A picture, so the details pane shows its preview.
        let picture = app.tables.staticTexts["Wallpaper.jpg"]
        XCTAssertTrue(picture.waitForExistence(timeout: Self.timeout))
        picture.click()
        app.typeKey("p", modifierFlags: [.command, .shift])
        settleScene()
        keep(app.windows.firstMatch.screenshot(), as: name("01-main", dark: dark))
    }

    // MARK: - Helpers

    /// A screenshot's name: the scene and its appearance, as 01-main-dark.
    private func name(_ scene: String, dark: Bool) -> String {
        scene + (dark ? "-dark" : "-light")
    }

    /// Starts Treewise on the sandbox volumes with the default settings.
    @MainActor
    private func launch(dark: Bool) throws -> XCUIApplication {
        guard let sandbox = ProcessInfo.processInfo.environment["TREEWISE_SANDBOX"] else {
            throw XCTSkip("Run with tools/build.sh screenshots, which attaches the sandbox.")
        }
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseSandbox", sandbox, "-TreewiseFreshSettings", "YES",
            "-TreewiseWindowSize", Self.windowSize, "-ApplePersistenceIgnoreState", "YES",
            "-TreewiseAppearance", dark ? "dark" : "light",
            // The download page is in English.
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: Self.timeout))
        return app
    }

    /// Goes to `path`, relative to the window's folder, by typing it in the
    /// address bar one key at a time; a tilde would be a dead key on some
    /// keyboard layouts.
    @MainActor
    private func go(to path: String, in app: XCUIApplication) {
        let folder = String(path.split(separator: "/").last ?? "")
        app.typeKey("l", modifierFlags: .command)
        XCTAssertTrue(app.textFields["Address"].waitForExistence(timeout: Self.timeout))
        app.typeKey("a", modifierFlags: .command)
        for character in path + "/" {
            let key = String(character)
            let isUpper = key != key.lowercased()
            app.typeKey(key.lowercased(), modifierFlags: isUpper ? .shift : [])
        }
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            app.windows(titled: folder).firstMatch.waitForExistence(timeout: Self.timeout),
            "the window shows \(folder)")
    }

    /// Lets the scene settle, so thumbnails and previews are in it.
    private func settleScene() {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settle)
    }

    @MainActor
    private func keep(_ screenshot: XCUIScreenshot, as name: String) {
        keep(screenshot.image, as: name)
    }

    private func keep(_ image: NSImage, as name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The part of a screenshot of the main display under `rect`, in points
    /// from its top left, as XCUITest gives frames.
    @MainActor
    private func crop(_ screenshot: XCUIScreenshot, to rect: CGRect) throws -> NSImage {
        let full = screenshot.image
        let image = try XCTUnwrap(full.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let main = try XCTUnwrap(NSScreen.screens.first).frame
        XCTAssertTrue(main.width >= rect.maxX, "the windows are on the main display")
        let scale = CGFloat(image.width) / main.width
        let pixels = CGRect(
            x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale,
            height: rect.height * scale)
        let cropped = try XCTUnwrap(image.cropping(to: pixels.integral))
        return NSImage(cgImage: cropped, size: rect.size)
    }
}
