import AppKit
import TreewiseCore
import TreewiseUI

/// A pattern's text as the overview shows it: small and monospaced, each field in its colour,
/// as the name it made shows them.
@MainActor
enum PatternText {
    static func coloured(_ pattern: String) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: pattern,
            attributes: [
                .font: NSFont.monospacedSystemFont(
                    ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize,
                    weight: .regular)
            ])
        for mark in FieldColors.marks(inPattern: pattern) {
            text.addAttribute(.backgroundColor, value: mark.color, range: mark.range)
        }
        return text
    }
}

/// Below an add-on in the overview's add-ons header: a newer version of the saved pattern
/// this folder uses, in the colours of its fields, with Use It and Keep Mine (ADR 0068).
@MainActor
enum NewerPatternVersion {
    private static let indent: CGFloat = 24
    private static let spacing: CGFloat = 8

    static func view(model: NameReviewModel, pattern: SavedPattern, moduleID: String) -> NSView {
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
                ?? NSImage())
        icon.contentTintColor = .secondaryLabelColor
        let notice = NSTextField(
            labelWithString: String(localized: "“\(pattern.name)” has a newer version:"))
        notice.font = .preferredFont(forTextStyle: .caption1)
        let text = NSTextField(labelWithAttributedString: PatternText.coloured(pattern.text))
        text.lineBreakMode = .byTruncatingTail
        let useIt = LinkButton(String(localized: "Use It")) {
            Task { await model.useNewerSavedPattern(for: moduleID) }
        }
        let keep = LinkButton(String(localized: "Keep Mine")) {
            Task { await model.keepPatternInsteadOfNewer(for: moduleID) }
        }
        let line = NSStackView(views: [icon, notice, text, useIt, keep])
        line.spacing = spacing
        line.edgeInsets = NSEdgeInsets(top: 0, left: indent, bottom: 0, right: 0)
        return line
    }
}
