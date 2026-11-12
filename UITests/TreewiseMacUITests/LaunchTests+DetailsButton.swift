import AppKit
import XCTest

/// The command bar's Details button looks on while the details pane shows, as a
/// toggle does, and off when it is hidden.
extension LaunchTests {
    /// How far apart a pixel's strongest and weakest colour channels must be for it
    /// to count as coloured rather than grey.
    private static let colouredSpread: CGFloat = 0.25
    /// How many coloured pixels make a button look on: more than stray anti-aliasing.
    private static let colouredPixelsWhenOn = 20

    @MainActor
    func testTheDetailsButtonLooksOnWhileThePaneShows() throws {
        let app = try launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.tables.staticTexts["Projects"].appeared(timeout: Self.launchTimeout))
        // A toggle, which AppKit exposes as a checkbox.
        let button = window.checkBoxes["Details"]
        XCTAssertTrue(button.appeared(timeout: Self.launchTimeout), "the command bar has Details")
        XCTAssertFalse(window.groups["Details"].exists, "the pane starts hidden")
        let off = Self.colouredPixels(in: try Self.image(of: button))

        button.click()

        XCTAssertTrue(
            window.groups["Details"].appeared(timeout: Self.launchTimeout), "the pane shows")
        let on = Self.colouredPixels(in: try Self.image(of: button))
        XCTAssertLessThan(off, Self.colouredPixelsWhenOn, "the button looks off: \(off)")
        XCTAssertGreaterThanOrEqual(on, Self.colouredPixelsWhenOn, "the button looks on: \(on)")
    }

    /// What the display that shows an element shows of it. XCUITest makes an
    /// element's own screenshot only on the main display, and the window may open
    /// on another one.
    @MainActor
    private static func image(of element: XCUIElement) throws -> CGImage {
        let rect = element.frame
        let screens = NSScreen.screens
        let top = try XCTUnwrap(screens.first).frame.maxY
        // XCUITest's frames start at the top left of the first display, AppKit's at its
        // bottom left.
        let index = try XCTUnwrap(
            screens.firstIndex {
                CGRect(
                    x: $0.frame.minX, y: top - $0.frame.maxY, width: $0.frame.width,
                    height: $0.frame.height
                ).contains(rect)
            }, "a display shows \(rect)")
        let frame = screens[index].frame
        let shot = XCUIScreen.screens[index].screenshot().image
        let image = try XCTUnwrap(shot.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let scale = CGFloat(image.width) / frame.width
        let pixels = CGRect(
            x: (rect.minX - frame.minX) * scale, y: (rect.minY - (top - frame.maxY)) * scale,
            width: rect.width * scale, height: rect.height * scale)
        return try XCTUnwrap(image.cropping(to: pixels.integral))
    }

    private static func colouredPixels(in image: CGImage) -> Int {
        let bitmap = NSBitmapImageRep(cgImage: image)
        var count = 0
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    continue
                }
                let channels = [colour.redComponent, colour.greenComponent, colour.blueComponent]
                if let high = channels.max(), let low = channels.min(),
                    high - low >= colouredSpread
                {
                    count += 1
                }
            }
        }
        return count
    }
}
