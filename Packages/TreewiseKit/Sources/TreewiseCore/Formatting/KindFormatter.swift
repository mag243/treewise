import Foundation

/// Writes an item's kind for the list: the provider's description when it has
/// one (`PDF document`), otherwise a generic one for the item's `ItemKind`
/// (ADR 0015).
public struct KindFormatter: Sendable {
    private let locale: Locale

    /// Creates a formatter for a locale.
    public init(locale: Locale) {
        self.locale = locale
    }

    /// Returns the text for the kind of `item`.
    public func string(for item: FileItem) -> String {
        if let description = item.kindDescription { return description }
        return switch item.kind {
        case .folder, .home:
            String(
                localized: "Folder", bundle: .module.localizationBundle(for: locale), locale: locale
            )
        case .file:
            String(
                localized: "Document", bundle: .module.localizationBundle(for: locale),
                locale: locale)
        case .package:
            String(
                localized: "Application", bundle: .module.localizationBundle(for: locale),
                locale: locale)
        case .volume:
            String(
                localized: "Volume", bundle: .module.localizationBundle(for: locale), locale: locale
            )
        case .cloud:
            String(
                localized: "Cloud storage", bundle: .module.localizationBundle(for: locale),
                locale: locale)
        case .computer:
            String(
                localized: "Computer", bundle: .module.localizationBundle(for: locale),
                locale: locale)
        }
    }
}
