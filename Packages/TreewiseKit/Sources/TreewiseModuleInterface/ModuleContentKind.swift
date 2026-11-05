/// A kind of content a module can ask for. Treewise extracts it from the items
/// the user chose (ADR 0057).
public enum ModuleContentKind: String, Hashable, Sendable, Codable, CaseIterable {
    /// The item's text, in reading order.
    case text
    /// The item's text with its position on each page.
    case positionedText
    /// Rendered images of the item's pages.
    case pageImages
}
