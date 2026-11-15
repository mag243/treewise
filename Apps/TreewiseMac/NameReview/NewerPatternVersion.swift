import AppKit
import TreewiseCore
import TreewiseUI

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
