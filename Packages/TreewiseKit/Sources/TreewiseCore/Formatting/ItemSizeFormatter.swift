import Foundation

/// Writes an item's size for the list in decimal units (`1.8 MB`), or two
/// dashes for containers and unknown sizes (PLAN.md §4.4).
public struct ItemSizeFormatter: Sendable {
    /// What a container or an unknown size reads as.
    public static let unknown = "--"

    private let locale: Locale

    /// Creates a formatter for a locale.
    public init(locale: Locale) {
        self.locale = locale
    }

    /// Returns the text for the size of `item`.
    public func string(for item: FileItem) -> String {
        guard !item.isContainer, let size = item.size else { return Self.unknown }
        return size.formatted(.byteCount(style: .file).locale(locale))
    }
}
