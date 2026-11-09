import Foundation
import TreewiseCore

/// What the details pane at the right of the window shows (M5b): for one item
/// its name, a preview and its kind, size, date and folder; for several their
/// count and total size.
public struct ItemDetails: Equatable {
    /// One line of the pane: what it is and its value.
    public struct Row: Equatable {
        public let label: String
        public let value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    /// The name of the item, the number of items, or that nothing is selected.
    public let title: String
    public let rows: [Row]
    /// The item to show a preview of: the one selected item, else `nil`.
    public let previewItem: FileItem.ID?

    /// Describes `items`, writing dates as the list does relative to `now`.
    public init(
        _ items: [FileItem], calendar: Calendar, locale: Locale, timeZone: TimeZone, now: Date
    ) {
        let bundle = Bundle.module.localizationBundle(for: locale)
        func text(_ key: String.LocalizationValue) -> String {
            String(localized: key, bundle: bundle, locale: locale)
        }
        switch items.count {
        case 0:
            title = text("No selection")
            rows = []
            previewItem = nil
        case 1:
            let item = items[0]
            title = item.name
            previewItem = item.id
            let dates = ItemDateFormatter(calendar: calendar, locale: locale, timeZone: timeZone)
            var rows = [
                Row(label: text("Kind"), value: KindFormatter(locale: locale).string(for: item))
            ]
            if let size = item.size {
                rows.append(Row(label: text("Size"), value: Self.size(size, locale)))
            }
            rows.append(
                Row(
                    label: text("Date Modified"),
                    value: dates.string(forModifiedOf: item, relativeTo: now)))
            if let parent = item.parentID {
                rows.append(Row(label: text("Where"), value: parent.shownPath))
            }
            self.rows = rows
        default:
            title = text("\(items.count) items")
            previewItem = nil
            let total = items.compactMap(\.size).reduce(0, +)
            rows = total > 0 ? [Row(label: text("Size"), value: Self.size(total, locale))] : []
        }
    }

    private static func size(_ bytes: Int64, _ locale: Locale) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))
    }
}
