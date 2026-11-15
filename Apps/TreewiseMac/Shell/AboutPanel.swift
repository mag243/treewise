import AppKit

/// About Treewise: AppKit's standard panel with the icon, the name, the version and the
/// copyright, and below them what Treewise is, its links and its licence (ADR 0081).
/// The licences of the parts it uses are in Help > Acknowledgements.
@MainActor
final class AboutPanel: NSObject {
    static let shared = AboutPanel()

    private nonisolated static let website = "https://treewise.m-domain.me/"
    private nonisolated static let source = "https://github.com/mag243/treewise"
    private nonisolated static let privacy = "https://treewise.m-domain.me/privacy.html"
    private nonisolated static let licence = "https://github.com/mag243/treewise/blob/main/LICENSE"
    /// The room between the credits' parts, in points.
    private static let partSpacing: CGFloat = 10

    @objc func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: Self.credits()])
        NSApp.activate()
    }

    /// The credits: a line on what Treewise is, its links, and its licence, centred.
    static func credits() -> NSAttributedString {
        let text = NSMutableAttributedString()
        let what = String(
            localized: "A file manager that works like Windows Explorer, made for the Mac.")
        text.append(part(what, color: .labelColor))
        let links = NSMutableAttributedString()
        let named = [
            (String(localized: "Website"), website), (String(localized: "GitHub"), source),
            (String(localized: "Privacy"), privacy),
        ]
        for (index, (title, url)) in named.enumerated() {
            if index > 0 { links.append(plain("  ·  ", color: .tertiaryLabelColor)) }
            links.append(link(title, to: url))
        }
        text.append(paragraph(links))
        // One sentence to translate, with the licence's name as a link inside it.
        // No-break spaces, so the name and the menu path wrap whole.
        let licenceName = "Mozilla\u{00A0}Public\u{00A0}License\u{00A0}2.0"
        let licenceLine = NSMutableAttributedString(
            attributedString: plain(
                String(localized: "Free and open source under the \(licenceName)."),
                color: .secondaryLabelColor))
        let nameRange = (licenceLine.string as NSString).range(of: licenceName)
        if nameRange.location != NSNotFound, let url = URL(string: licence) {
            licenceLine.addAttribute(.link, value: url, range: nameRange)
        }
        text.append(paragraph(licenceLine))
        let help = String(localized: "Help")
        let menuPath = "\(help)\u{00A0}>\u{00A0}\(String(localized: "Acknowledgements"))"
        let acknowledgements = String(
            localized: "The licences of the parts it uses are in \(menuPath).")
        text.append(part(acknowledgements, color: .secondaryLabelColor, last: true))
        return text
    }

    private static func part(_ string: String, color: NSColor, last: Bool = false)
        -> NSAttributedString
    {
        paragraph(plain(string, color: color), last: last)
    }

    /// A centred paragraph with room below it, except for the last.
    private static func paragraph(_ content: NSAttributedString, last: Bool = false)
        -> NSAttributedString
    {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = last ? 0 : partSpacing
        let result = NSMutableAttributedString(attributedString: content)
        if !last { result.append(NSAttributedString(string: "\n")) }
        result.addAttribute(
            .paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    private static func plain(_ string: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: color,
            ])
    }

    private static func link(_ title: String, to address: String) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        ]
        if let url = URL(string: address) { attributes[.link] = url }
        return NSAttributedString(string: title, attributes: attributes)
    }
}
