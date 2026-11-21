import ImageIO
import UniformTypeIdentifiers
import XCTest

/// The App Store's screenshots of the iOS app (ADR 0118, 0145): the demo folders in English,
/// Dutch and German, each screen kept as `appstore-<device>-<locale>-<NN-name>`, which
/// `tools/build.sh appstorescreenshots` copies out for the uploader. The device's walk is the
/// one `APPSTORE_DEVICE` names. Not a test of behaviour: `iosuitest` skips this class.
final class AppStoreScreenshotTests: XCTestCase {
    static let timeout: TimeInterval = 10
    /// How long a screen settles before it is kept: a menu or a sheet opens with an animation
    /// that offers nothing to wait for.
    private static let settle: TimeInterval = 1.5
    static let longPress: TimeInterval = 1
    private static let pickUp: TimeInterval = 1
    private static let rest: TimeInterval = 1

    /// The device whose screenshots the walk makes, as `tools/build.sh` names it.
    enum Device: String {
        case ipad, iphone
        case duoOuter = "duo-outer"
        case duoInner = "duo-inner"

        static var current: Device {
            ProcessInfo.processInfo.environment["APPSTORE_DEVICE"].flatMap(Device.init) ?? .ipad
        }

        /// Whether the folder shows as on the iPhone (ADR 0132), without a sidebar beside it.
        var isCompact: Bool { self == .iphone || self == .duoOuter }

        /// The size App Store Connect takes, in pixels, where the screen's differs from it:
        /// the Duo's inner display measures 950⅔ × 668⅔ points, a pixel short each way.
        var pixelSize: CGSize? { self == .duoInner ? CGSize(width: 2853, height: 2007) : nil }
    }

    /// The demo's names and the commands' titles the walk looks for, in one language.
    struct Language {
        let locale: String
        let code: String
        let documents: String
        let photos: String
        let summer: String
        let archive: String
        let budget: String
        /// A file near the top of the documents, selected with the budget.
        let nearTop: String
        let template: String
        /// The commands' titles by their English ones; English where none is given.
        let titles: [String: String]

        /// The title of the command `english`.
        func title(_ english: String) -> String { titles[english] ?? english }
    }

    static let camera = "IMG_4127.jpg"

    private static let languages = [
        Language(
            locale: "en-US", code: "en", documents: "Documents", photos: "Photos",
            summer: "Summer 2026", archive: "Archive", budget: "Budget 2026.xlsx",
            nearTop: "Birthdays.txt", template: "Household Year", titles: [:]),
        Language(
            locale: "nl-NL", code: "nl", documents: "Documenten", photos: "Foto’s",
            summer: "Zomer 2026", archive: "Archief", budget: "Begroting 2026.xlsx",
            nearTop: "Autoverzekering.pdf", template: "Huishoudjaar",
            titles: [
                "Select": "Selecteer", "Actions": "Acties", "Done": "Gereed",
                "Rename with Suggestions…": "Wijzig naam met voorstellen…",
                "Folder Structure": "Mapstructuur",
                "New Folders from Template": "Nieuwe mappen uit sjabloon",
                "Create Folders": "Maak mappen", "Move to…": "Verplaats naar…",
                "Copy": "Kopieer", "Paste": "Plak", "Open in New Window": "Open in nieuw venster",
            ]),
        Language(
            locale: "de-DE", code: "de", documents: "Dokumente", photos: "Fotos",
            summer: "Sommer 2026", archive: "Archiv", budget: "Budget 2026.xlsx",
            nearTop: "Autoversicherung.pdf", template: "Haushaltsjahr",
            titles: [
                "Select": "Auswählen", "Actions": "Aktionen", "Done": "Fertig",
                "Rename with Suggestions…": "Mit Vorschlägen umbenennen …",
                "Folder Structure": "Ordnerstruktur",
                "New Folders from Template": "Neue Ordner aus Vorlage",
                "Create Folders": "Ordner anlegen", "Move to…": "Bewegen nach…",
                "Copy": "Kopieren", "Paste": "Einsetzen",
                "Open in New Window": "In neuem Fenster öffnen",
            ]),
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        XCUIDevice.shared.appearance = .light
        for language in Self.languages {
            switch Device.current {
            case .ipad: walkIPad(language)
            case .iphone: walkIPhone(language)
            case .duoOuter: walkDuoOuter(language)
            case .duoInner: walkDuoInner(language)
            }
        }
        if Device.current == .ipad { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    /// Starts Treewise on fresh demo folders in `language` and shows its documents.
    @MainActor
    func open(_ language: Language) -> XCUIApplication {
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
    func drag(_ item: XCUIElement, onto target: XCUIElement) {
        item.press(
            forDuration: Self.pickUp, thenDragTo: target, withVelocity: .slow,
            thenHoldForDuration: Self.rest)
    }

    /// Keeps the screen as a PNG without alpha, which App Store Connect refuses: drawn
    /// upright first, as the simulator keeps a landscape screenshot's pixels in portrait, at
    /// the size App Store Connect takes, then into a bitmap with no alpha, which ImageIO
    /// writes as RGB. The Duo's inner display is the last of the screens, as `main` stays
    /// the outer one.
    @MainActor
    func keep(_ name: String, of language: Language) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settle)
        let device = Device.current
        let screen = device == .duoInner ? XCUIScreen.screens.last ?? .main : .main
        let image = screen.screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = device.pixelSize == nil ? image.scale : 1
        let size = device.pixelSize ?? image.size
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let attachment = XCTAttachment(
            data: Self.pngWithoutAlpha(upright.cgImage) ?? Data(),
            uniformTypeIdentifier: UTType.png.identifier)
        attachment.name = "appstore-\(device.rawValue)-\(language.locale)-\(name)"
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
