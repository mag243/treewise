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
        return Self.bytes(size, locale: locale)
    }

    /// A number of bytes in decimal units, as Finder writes a file's size: the one way
    /// Treewise writes a size, in the list, the details, the status bar and progress.
    public static func bytes(_ count: Int64, locale: Locale) -> String {
        count.formatted(.byteCount(style: .file).locale(locale))
    }
}
