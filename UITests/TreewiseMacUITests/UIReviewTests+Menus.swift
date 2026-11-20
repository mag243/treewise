import AppKit
import XCTest

/// The command bar's menus in the UI review (ADR 0103): whether their items show the
/// symbols they ask for, which macOS 27 hides unless asked (ADR 0052). A menu is a window
/// of its own, so the screen is taken where the browser window is.
extension UIReviewTests {
    /// The command bar's menus with symbols, by their button's name.
    private static let menusWithSymbols = ["New", "View"]

    @MainActor
    func reviewCommandBarMenus(in window: XCUIElement, app: XCUIApplication, appearance: String?) {
        for name in Self.menusWithSymbols {
            let button = window.menuButtons[name]
            press(button)
            settleScreen()
            keepScreen(
                over: window, as: "browser-menu-\(slug(name))", appearance: appearance)
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    /// The context menu of a file and of a folder in the root (ADR 0142): what shows, its
    /// groups and its submenus' lines.
    @MainActor
    func reviewContextMenus(in window: XCUIElement, app: XCUIApplication, appearance: String?) {
        for (name, shot) in [("Notes.md", "file"), ("Projects", "folder")] {
            let item = window.tables.staticTexts[name]
            XCTAssertTrue(item.waitForExistence(timeout: Self.timeout), "\(name) shows")
            press(item, in: window.scrollViews.firstMatch, .rightClick)
            settleScreen()
            keepScreen(over: window, as: "browser-context-\(shot)", appearance: appearance)
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    /// Keeps the part of the screen under `window`, with what lies over it, as a screen of
    /// the review. Nothing in a menu is checked: XCUITest does not see a menu item's symbol,
    /// so the screenshot is looked at.
    @MainActor
    private func keepScreen(over window: XCUIElement, as name: String, appearance: String?) {
        let full = appearance.map { "\(name)-\($0)" } ?? name
        let screen = XCUIScreen.main.screenshot().image
        let frame = window.frame
        // The window's frame is in points from the main screen's top left; the screenshot
        // is in pixels.
        guard let image = screen.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let points = NSScreen.screens.first?.frame.width
        else { return }
        let scale = CGFloat(image.width) / points
        let area = CGRect(
            x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale,
            height: frame.height * scale)
        guard let part = image.cropping(to: area) else { return }
        let screenshot = XCTAttachment(image: NSImage(cgImage: part, size: frame.size))
        screenshot.name = "uireview-\(full)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let findings = XCTAttachment(
            data: (try? JSONEncoder().encode([UIReviewFinding]())) ?? Data(),
            uniformTypeIdentifier: "public.json")
        findings.name = "uireview-\(full).findings"
        findings.lifetime = .keepAlways
        add(findings)
    }
}
