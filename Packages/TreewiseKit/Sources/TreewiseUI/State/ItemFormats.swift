import Foundation
import TreewiseCore

/// The texts of an item's date, size and kind in a list, alike on the Mac and the iPad,
/// in the user's calendar, language and time zone (PLAN.md §4.4).
public struct ItemFormats {
    private let dates = ItemDateFormatter(
        calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent,
        timeZone: .autoupdatingCurrent)
    private let sizes = ItemSizeFormatter(locale: .autoupdatingCurrent)
    private let kinds = KindFormatter(locale: .autoupdatingCurrent)

    public init() {}

    /// When the item was changed: `Today at 18:31`, or its day alone when the file
    /// system gives no time.
    public func date(of item: FileItem, relativeTo now: Date = .now) -> String {
        dates.string(forModifiedOf: item, relativeTo: now)
    }

    public func size(of item: FileItem) -> String {
        sizes.string(for: item)
    }

    public func kind(of item: FileItem) -> String {
        kinds.string(for: item)
    }
}
