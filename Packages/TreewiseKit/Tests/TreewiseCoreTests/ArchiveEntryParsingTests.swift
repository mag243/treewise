import Foundation
import Testing

@testable import TreewiseCore

/// Reading the lines of `tar -tv` (ADR 0076).
@Suite struct ArchiveEntryParsingTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
            ?? .distantPast
    }

    private static let now = date(2026, 11, 9, 18, 0)

    private func parse(_ line: String, now: Date = Self.now) -> ArchiveEntry? {
        ArchiveEntry(listingLine: line, now: now, calendar: Self.calendar)
    }

    @Test func readsAFile() throws {
        let entry = try #require(
            parse("-rw-r--r--  0 501    0        5242880 Nov  9 17:13 ./big.bin"))
        #expect(entry.storedName == "./big.bin")
        #expect(!entry.isFolder)
        #expect(entry.size == 5_242_880)
        #expect(entry.modified == Self.date(2026, 11, 9, 17, 13))
        #expect(entry.modifiedHasTime)
    }

    @Test func readsAFolder() throws {
        let entry = try #require(parse("drwxr-xr-x  0 501    0           0 Nov  9 17:13 ./deep/"))
        #expect(entry.storedName == "./deep/")
        #expect(entry.isFolder)
    }

    @Test func anOlderEntryHasADayButNoTime() throws {
        let entry = try #require(parse("-rw-r--r--  0 501    0           2 Jan  2  2020 ./old.txt"))
        #expect(entry.modified == Self.date(2020, 1, 2))
        #expect(!entry.modifiedHasTime)
        #expect(entry.storedName == "./old.txt")
    }

    @Test(arguments: [
        ("Dec  5 17:13", date(2026, 11, 9, 18, 0), date(2026, 12, 5, 17, 13)),
        ("Nov  9 17:13", date(2027, 1, 15, 12, 0), date(2026, 11, 9, 17, 13)),
        ("Jan 15 12:00", date(2026, 11, 9, 18, 0), date(2027, 1, 15, 12, 0)),
    ])
    func aTimeWithoutAYearIsTheOneNearestToNow(listed: String, now: Date, expected: Date) throws {
        let entry = try #require(parse("-rw-r--r--  0 501  0  1 \(listed) a.txt", now: now))
        #expect(entry.modified == expected)
    }

    @Test func aLinkIsNamedWithoutItsTarget() throws {
        let entry = try #require(
            parse("lrwxr-xr-x  0 501    0           0 Nov  9 17:20 ./ln -> target"))
        #expect(entry.storedName == "./ln")
        #expect(!entry.isFolder)
    }

    @Test func aHardLinkIsNamedWithoutItsTarget() throws {
        let entry = try #require(
            parse("hrw-r--r--  0 501    0           0 Nov  9 17:20 ./copy link to ./original"))
        #expect(entry.storedName == "./copy")
    }

    @Test func anArrowInAFileNameStays() throws {
        let entry = try #require(parse("-rw-------  0 0  0  1 Nov  9 17:20 sp ace -> x.txt"))
        #expect(entry.storedName == "sp ace -> x.txt")
    }

    @Test(arguments: [
        (#"own\nline.txt"#, "own\nline.txt"),
        (#"tab\there"#, "tab\there"),
        (#"back\\slash"#, "back\\slash"),
        (#"caf\303\251.txt"#, "café.txt"),
        ("café.txt", "café.txt"),
    ])
    func undoesTheEscapesOfANameAsListed(listed: String, name: String) throws {
        let entry = try #require(parse("-rw-------  0 0  0  1 Nov  9 17:20 \(listed)"))
        #expect(entry.storedName == name)
    }

    @Test func anOwnerNameMayHoldSpaces() throws {
        let entry = try #require(parse("-rw-r--r--  1 Jan Jansen  staff  12 Nov  9 17:13 a.txt"))
        #expect(entry.size == 12)
        #expect(entry.storedName == "a.txt")
    }

    @Test(arguments: ["", "tar: something went wrong", "-rw-r--r-- no date here"])
    func aLineThatIsNoEntryGivesNothing(line: String) {
        #expect(parse(line) == nil)
    }
}
