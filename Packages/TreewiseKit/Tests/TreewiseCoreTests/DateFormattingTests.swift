import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Dates in the list, PLAN.md §4.4, relative to the fixture's clock.
@Suite struct DateFormattingTests {
    private let formatter = ItemDateFormatter(
        calendar: Fixture.calendar, locale: Locale(identifier: "en_GB"), timeZone: Fixture.timeZone)

    private func text(_ date: String) -> String {
        formatter.string(for: Fixture.date(date), relativeTo: Fixture.now)
    }

    @Test func writesTodayWithTheTime() {
        #expect(text("2026-10-25 18:31") == "Today at 18:31")
    }

    @Test func writesYesterdayWithTheTime() {
        #expect(text("2026-10-24 09:02") == "Yesterday at 09:02")
    }

    @Test func writesOlderDatesInFull() {
        #expect(text("2026-10-23 21:14") == "23 Oct 2026 at 21:14")
    }

    @Test func writesTheStartOfTodayAsToday() {
        #expect(text("2026-10-25 00:00") == "Today at 00:00")
    }

    @Test func writesFutureDatesInFull() {
        #expect(text("2026-10-26 08:00") == "26 Oct 2026 at 08:00")
    }

    @Test func writesTwoDashesForAnUnknownDate() {
        #expect(formatter.string(for: nil, relativeTo: Fixture.now) == "--")
    }

    @Test func usesTheTimeZoneItIsGiven() {
        let utc = ItemDateFormatter(
            calendar: Fixture.calendar, locale: Locale(identifier: "en_GB"), timeZone: .gmt)
        #expect(
            utc.string(for: Fixture.date("2026-10-23 21:14"), relativeTo: Fixture.now)
                == "23 Oct 2026 at 19:14")
    }

    @Test(
        .tags(.localization), .needsCompiledStrings,
        arguments: [("nl_NL", "Vandaag om 18:31"), ("de_DE", "Heute, 18:31")])
    func writesTodayInTheLanguageOfTheLocale(_ identifier: String, _ expected: String) {
        let formatter = ItemDateFormatter(
            calendar: Fixture.calendar, locale: Locale(identifier: identifier),
            timeZone: Fixture.timeZone)
        #expect(
            formatter.string(for: Fixture.date("2026-10-25 18:31"), relativeTo: Fixture.now)
                == expected)
    }

    private func item(modified: Date?, hasTime: Bool) -> FileItem {
        var item = FileItem(
            id: "a", name: "a", kind: .file, volume: VolumeID("v"), modified: modified)
        item.modifiedHasTime = hasTime
        return item
    }

    @Test func anItemKnownByItsDayShowsNoTime() {
        let item = item(modified: Fixture.date("2020-01-02 00:00"), hasTime: false)
        #expect(formatter.string(forModifiedOf: item, relativeTo: Fixture.now) == "2 Jan 2020")
    }

    @Test func anItemWithATimeReadsAsAnyDate() {
        let item = item(modified: Fixture.date("2026-10-25 18:31"), hasTime: true)
        #expect(formatter.string(forModifiedOf: item, relativeTo: Fixture.now) == "Today at 18:31")
    }

    @Test func anItemWithoutADateIsUnknown() {
        let item = item(modified: nil, hasTime: false)
        #expect(formatter.string(forModifiedOf: item, relativeTo: Fixture.now) == "--")
    }
}
