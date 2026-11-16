import ImageIO
import UniformTypeIdentifiers
import XCTest

/// The App Store's screenshots of the iPad app (ADR 0118): the demo folders in English,
/// Dutch and German, each screen kept as `appstore-<locale>-<NN-name>`, which
/// `tools/build.sh appstorescreenshots` copies out for the uploader. Not a test of behaviour:
/// `iosuitest` skips this class.
final class AppStoreScreenshotTests: XCTestCase {
    static let timeout: TimeInterval = 10
    /// How long a screen settles before it is kept: a menu or a sheet opens with an animation
    /// that offers nothing to wait for.
    private static let settle: TimeInterval = 1.5
    private static let longPress: TimeInterval = 1
    private static let pickUp: TimeInterval = 1
    private static let rest: TimeInterval = 1
    private static let emptyPoint = CGVector(dx: 0.5, dy: 0.97)

    /// The demo's names the walk looks for, as `DemoTree` makes them.
    private struct Language {
        let locale: String
        let code: String
        let documents: String
        let archive: String
        let budget: String
        let lighthouse: String
    }

    private static let languages = [
        Language(
            locale: "en-US", code: "en", documents: "Documents", archive: "Archive",
            budget: "Budget 2026.xlsx", lighthouse: "Lighthouse.jpg"),
        Language(
            locale: "nl-NL", code: "nl", documents: "Documenten", archive: "Archief",
            budget: "Begroting 2026.xlsx", lighthouse: "Vuurtoren.jpg"),
        Language(
            locale: "de-DE", code: "de", documents: "Dokumente", archive: "Archiv",
            budget: "Budget 2026.xlsx", lighthouse: "Leuchtturm.jpg"),
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        XCUIDevice.shared.appearance = .light
        for language in Self.languages {
            try walk(language)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    @MainActor
    private func walk(_ language: Language) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        var app = open(language)
        keep("01-folder", of: language)

        drag(row(language.budget, in: app), onto: row(language.archive, in: app))
        XCTAssertTrue(
            app.switches.firstMatch.waitForExistence(timeout: Self.timeout), "the conflict sheet")
        keep("02-conflict", of: language)
        app.terminate()

        app = open(language)
        row(language.budget, in: app).press(forDuration: Self.longPress)
        keep("03-context-menu", of: language)
        app.coordinate(withNormalizedOffset: Self.emptyPoint).tap()

        app.descendants(matching: .any)["viewMenu"].firstMatch.tap()
        keep("04-view-menu", of: language)
        app.coordinate(withNormalizedOffset: Self.emptyPoint).tap()

        row(language.lighthouse, in: app).tap()
        XCTAssertTrue(
            app.otherElements["QLPreviewControllerView"].waitForExistence(timeout: Self.timeout))
        keep("05-quick-look", of: language)
        app.terminate()

        XCUIDevice.shared.orientation = .portrait
        app = open(language)
        keep("06-portrait", of: language)
        app.terminate()
    }

    /// Starts Treewise on fresh demo folders in `language` and shows its documents.
    @MainActor
    private func open(_ language: Language) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-TreewiseTestState", UUID().uuidString, "-TreewiseTestDemo", "YES",
            "-AppleLanguages", "(\(language.code))",
            "-AppleLocale", language.locale.replacingOccurrences(of: "-", with: "_"),
        ]
        app.launch()
        let documents = sidebar(of: app).staticTexts[language.documents]
        if documents.waitForExistence(timeout: Self.timeout), documents.isHittable {
            documents.tap()
        }
        XCTAssertTrue(row(language.budget, in: app).waitForExistence(timeout: Self.timeout))
        return app
    }

    @MainActor
    private func drag(_ item: XCUIElement, onto target: XCUIElement) {
        item.press(
            forDuration: Self.pickUp, thenDragTo: target, withVelocity: .slow,
            thenHoldForDuration: Self.rest)
    }

    /// Keeps the screen as a PNG without alpha, which App Store Connect refuses: drawn
    /// upright first, as the simulator keeps a landscape screenshot's pixels in portrait,
    /// then into a bitmap with no alpha, which ImageIO writes as RGB.
    @MainActor
    private func keep(_ name: String, of language: Language) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settle)
        let image = XCUIScreen.main.screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
        }
        let attachment = XCTAttachment(
            data: Self.pngWithoutAlpha(upright.cgImage) ?? Data(),
            uniformTypeIdentifier: UTType.png.identifier)
        attachment.name = "appstore-\(language.locale)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func pngWithoutAlpha(_ image: CGImage?) -> Data? {
        guard let image, let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = NSMutableData()
        guard let opaque = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, opaque, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
