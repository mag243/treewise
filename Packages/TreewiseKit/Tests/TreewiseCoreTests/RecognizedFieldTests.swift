import Foundation
import Testing

@testable import TreewiseCore

/// What an add-on recognizes, shown with its kind and an example (ADR 0092).
@Suite struct RecognizedFieldTests {
    private static let today: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 13)) ?? .distantPast
    }()

    private static func field(_ token: String) -> RecognizedField {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return RecognizedField(
            token, today: today, calendar: calendar, locale: Locale(identifier: "en"))
    }

    @Test(arguments: [
        ("{date}", RecognizedField.Kind.date, "2026-11-13"),
        ("{date:dd.MM.yyyy}", .date, "13.11.2026"),
        ("{year}", .date, "2026"),
        ("{seq}", .series, "1, 2, 3 …"),
        ("{seq:2}", .series, "1–2"),
        ("{seq:4}", .series, "1–4"),
        ("{seq:12}", .series, "01–12"),
        ("{seq:24:1}", .series, "1–24"),
        ("{seq:2-24}", .series, "02–24"),
        ("{seq:5-}", .series, "5, 6, 7 …"),
        ("{seq:2,4,6,8}", .series, "2 4 6 8"),
        ("{seq:2,4,6,8:2}", .series, "02 04 06 08"),
        ("{text}", .text, "words"),
        ("{folder}", .text, "Tax"),
        ("<…|…>", .choice, "one of several"),
    ])
    func showsAKindAndAnExample(token: String, kind: RecognizedField.Kind, example: String) {
        let field = Self.field(token)
        #expect(field.token == token)
        #expect(field.kind == kind)
        #expect(field.example == example)
    }

    @Test func showsAFieldItDoesNotKnowAsTextWithoutAnExample() {
        let field = Self.field("{company}")
        #expect(field.kind == .text)
        #expect(field.example.isEmpty)
    }

    @Test func showsASeriesItCannotReadWithoutAnExample() {
        let field = Self.field("{seq:x}")
        #expect(field.kind == .series)
        #expect(field.example.isEmpty)
    }
}
