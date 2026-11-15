import Foundation

/// Writes an item's kind for the list: the provider's description when it has
/// one (`PDF document`), otherwise a generic one for the item's `ItemKind`
/// (ADR 0015).
public struct KindFormatter: Sendable {
    /// The generic text of each kind, looked up once: sorting by kind asks for it
    /// twice for every comparison.
    private let generic: [ItemKind: String]

    /// Creates a formatter for a locale.
    public init(locale: Locale) {
        let bundle = Bundle.module.localizationBundle(for: locale)
        func text(_ key: String.LocalizationValue) -> String {
            String(localized: key, bundle: bundle, locale: locale)
        }
        let folder = text("Folder")
        generic = [
            .folder: folder, .home: folder, .file: text("Document"), .package: text("Application"),
            .volume: text("Volume"), .cloud: text("Cloud storage"), .computer: text("Computer"),
        ]
    }

    /// Returns the text for the kind of `item`.
    public func string(for item: FileItem) -> String {
        item.kindDescription ?? generic[item.kind] ?? ""
    }
}
