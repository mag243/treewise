import Foundation
import TreewiseCore

/// The text of the status bar under a pane, as in the prototype:
/// "8 items, 245.3 GB available", or "2 of 8 items selected, 1.8 MB" while
/// items are selected.
public enum StatusLine {
    /// Returns the status text. The free space is left out when unknown, the
    /// selection's size when it is zero (a selection of folders).
    public static func text(
        itemCount: Int, selectedCount: Int, selectedSize: Int64? = nil, availableCapacity: Int64?,
        locale: Locale
    ) -> String {
        let bundle = Bundle.module.localizationBundle(for: locale)
        let items = String(localized: "\(itemCount) items", bundle: bundle, locale: locale)
        if selectedCount > 0 {
            let selected = String(
                localized: "\(selectedCount) of \(items) selected", bundle: bundle, locale: locale)
            guard let selectedSize, selectedSize > 0 else { return selected }
            return String(
                localized: "\(selected), \(size(selectedSize, locale))", bundle: bundle,
                locale: locale)
        }
        guard let availableCapacity else { return items }
        return String(
            localized: "\(items), \(size(availableCapacity, locale)) available", bundle: bundle,
            locale: locale)
    }

    private static func size(_ bytes: Int64, _ locale: Locale) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))
    }
}
