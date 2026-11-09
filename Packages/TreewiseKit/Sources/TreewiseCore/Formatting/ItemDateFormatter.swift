import Foundation

/// Writes an item's date for the list: `Today at 18:31`, `Yesterday at 09:02`,
/// otherwise `24 Oct 2026 at 21:14` in the conventions of the locale
/// (PLAN.md §4.4, ADR 0015).
///
/// Uses `DateFormatter` rather than `Date.FormatStyle`: its short time style
/// follows the locale's own pattern (`09:02` in en_GB and Dutch), where
/// `.shortened` drops the leading zero. A `DateFormatter` is not `Sendable`,
/// so neither is this type; keep one per actor.
public final class ItemDateFormatter {
    /// What an unknown date reads as.
    public static let unknown = "--"

    private let calendar: Calendar
    private let locale: Locale
    private let timeFormatter: DateFormatter
    private let dateTimeFormatter: DateFormatter
    private let dayFormatter: DateFormatter

    /// Creates a formatter for a calendar, locale and time zone.
    public init(calendar: Calendar, locale: Locale, timeZone: TimeZone) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.locale = locale
        timeFormatter = Self.formatter(dateStyle: .none, calendar: calendar, locale: locale)
        dateTimeFormatter = Self.formatter(dateStyle: .medium, calendar: calendar, locale: locale)
        dayFormatter = Self.formatter(
            dateStyle: .medium, timeStyle: .none, calendar: calendar, locale: locale)
    }

    /// Returns the text for `date`, with today and yesterday measured from `now`.
    public func string(for date: Date?, relativeTo now: Date) -> String {
        guard let date else { return Self.unknown }
        let time = timeFormatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) {
            return String(
                localized: "Today at \(time)", bundle: .module.localizationBundle(for: locale),
                locale: locale)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return String(
                localized: "Yesterday at \(time)", bundle: .module.localizationBundle(for: locale),
                locale: locale)
        }
        return dateTimeFormatter.string(from: date)
    }

    /// Returns the text for when an item last changed; an item known by its
    /// day alone shows no time.
    public func string(forModifiedOf item: FileItem, relativeTo now: Date) -> String {
        guard !item.modifiedHasTime, let date = item.modified else {
            return string(for: item.modified, relativeTo: now)
        }
        return dayFormatter.string(from: date)
    }

    private static func formatter(
        dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style = .short,
        calendar: Calendar, locale: Locale
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }
}
