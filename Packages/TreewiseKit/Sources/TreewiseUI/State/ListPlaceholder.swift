import Foundation
import TreewiseCore

/// What a list without rows says: the folder is empty, or a search found nothing.
public enum ListPlaceholder {
    /// Returns the text for an empty list with search text `query`.
    public static func text(query: String, locale: Locale) -> String {
        let bundle = Bundle.module.localizationBundle(for: locale)
        return query.isEmpty
            ? String(localized: "Folder is empty", bundle: bundle, locale: locale)
            : String(localized: "No results for “\(query)”", bundle: bundle, locale: locale)
    }
}
