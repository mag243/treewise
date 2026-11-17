import XCTest

/// What the iPad's and the iPhone's UI reviews share (ADR 0115, 0132): each screen in
/// landscape and portrait, in light or in each appearance `UIREVIEW_APPEARANCES` names
/// (`light,dark`), kept as a screenshot with the findings of `UIReviewChecks` beside it.
enum UIReviewWalk {
    /// How long a screen settles before it is looked at: a menu or a sheet opens with an
    /// animation that offers nothing to wait for. The review tests no behaviour.
    static let settle: TimeInterval = 1

    static let orientations: [(name: String, orientation: UIDeviceOrientation)] = [
        ("landscape", .landscapeLeft), ("portrait", .portrait),
    ]

    static var appearances: [String] {
        let named = ProcessInfo.processInfo.environment["UIREVIEW_APPEARANCES"] ?? ""
        let list = named.split(separator: ",").map { String($0) }
        return list.isEmpty ? ["light"] : list
    }

    /// The device's name in the screens' names, as `UIREVIEW_DEVICE` gives it: empty on the
    /// pinned iPad, `11inch` on the smaller one, `iphone` on the iPhone (ADR 0115, 0132).
    static var device: String {
        ProcessInfo.processInfo.environment["UIREVIEW_DEVICE"] ?? ""
    }

    /// The screenshot drawn as the screen is held: the simulator keeps a landscape one's
    /// pixels in portrait with a note of how to turn them, which the report does not read.
    @MainActor
    static func upright(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
        }
    }
}

extension XCTestCase {
    /// Runs `walk` in each orientation and appearance, with its variant's name.
    @MainActor
    func eachReviewVariant(_ walk: (String) throws -> Void) throws {
        for appearance in UIReviewWalk.appearances {
            XCUIDevice.shared.appearance = appearance == "dark" ? .dark : .light
            for (name, orientation) in UIReviewWalk.orientations {
                XCUIDevice.shared.orientation = orientation
                let device = UIReviewWalk.device
                let place = device.isEmpty ? name : "\(name)-\(device)"
                try walk("\(place)-\(appearance)")
            }
        }
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    /// Keeps a screenshot of the screen and what the checks found on it, both named
    /// `uireview-<name>-<variant>`, for the report.
    @MainActor
    func review(_ app: XCUIApplication, as name: String, variant: String) {
        settleScreen()
        let full = "\(name)-\(variant)"
        let screenshot = XCTAttachment(
            image: UIReviewWalk.upright(XCUIScreen.main.screenshot().image))
        screenshot.name = "uireview-\(full)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        var found: [UIReviewFinding]
        do {
            found = UIReviewChecks.findings(in: try app.snapshot(), readableLines: true)
        } catch {
            found = [UIReviewFinding(check: "snapshot", element: "app", detail: "\(error)")]
        }
        let findings = XCTAttachment(
            data: (try? JSONEncoder().encode(found)) ?? Data(), uniformTypeIdentifier: "public.json"
        )
        findings.name = "uireview-\(full).findings"
        findings.lifetime = .keepAlways
        add(findings)
    }

    func settleScreen() {
        _ = XCTWaiter.wait(
            for: [XCTestExpectation(description: "settle")], timeout: UIReviewWalk.settle)
    }
}
