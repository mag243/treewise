import Foundation
import TreewiseCore

/// The standard test tree: the demo file system of the prototype, with full file
/// names.
public enum Fixture {
    /// The time zone the fixture's dates are written in.
    public static let timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .gmt

    /// A Gregorian calendar in the fixture's time zone.
    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    /// The fixture's clock: 25 October 2026 at 19:00, so `todo.txt` (18:31) is
    /// from today and the screenshot (24 October) from yesterday.
    public static let now = date("2026-10-25 19:00")

    /// The tree with three locations: Macintosh HD, iCloud Drive and an external drive.
    public static let standard = InMemoryFileSystem(
        FixtureRows.all.map(item),
        favorites: ["apps", "desktop", "documents", "downloads", "pictures", "projects"],
        capacities: ["hd": 245_300_000_000, "icloud": 1_200_000_000_000, "usb": 612_800_000_000])

    /// Parses a fixture date written as `yyyy-MM-dd HH:mm` in the fixture's time zone.
    ///
    /// Precondition: `text` is a valid date in that format.
    public static func date(_ text: String) -> Date {
        let numbers = text.split(whereSeparator: { "- :".contains($0) }).compactMap { Int($0) }
        guard numbers.count == 5 else {
            preconditionFailure("text is a valid date in that format: \(text)")
        }
        let components = DateComponents(
            year: numbers[0], month: numbers[1], day: numbers[2], hour: numbers[3],
            minute: numbers[4])
        guard let date = calendar.date(from: components) else {
            preconditionFailure("text is a valid date in that format: \(text)")
        }
        return date
    }

    private static func item(_ row: FixtureRows.Row) -> FileItem {
        FileItem(
            id: FileItem.ID(row.id),
            name: row.name,
            kind: row.kind,
            parentID: row.parent.map { FileItem.ID($0) },
            volume: VolumeID(FixtureRows.location(of: row.id)),
            modified: row.date.map(date),
            size: row.size,
            kindDescription: row.kindDescription)
    }
}
