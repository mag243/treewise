import Foundation

/// Content extracted from an item. A field is nil when the module did not declare
/// it or when it could not be extracted (ADR 0057).
public struct ModuleContent: Hashable, Sendable, Codable {
    /// The item's text, in reading order.
    public let text: String?
    /// The item's text with its position on each page.
    public let positionedText: [PositionedText]?
    /// PNG images of the item's pages.
    public let pageImages: [Data]?

    /// Creates content.
    public init(
        text: String? = nil, positionedText: [PositionedText]? = nil, pageImages: [Data]? = nil
    ) {
        self.text = text
        self.positionedText = positionedText
        self.pageImages = pageImages
    }
}

/// A piece of text and where it stands on a page.
public struct PositionedText: Hashable, Sendable, Codable {
    /// The text.
    public let text: String
    /// The page's index, from 0.
    public let page: Int
    /// The left edge, as a fraction of the page's width from its left.
    public let x: Double
    /// The top edge, as a fraction of the page's height from its top.
    public let y: Double
    /// The width, as a fraction of the page's width.
    public let width: Double
    /// The height, as a fraction of the page's height.
    public let height: Double

    /// Creates a positioned text.
    public init(text: String, page: Int, x: Double, y: Double, width: Double, height: Double) {
        self.text = text
        self.page = page
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
