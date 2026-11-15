import Foundation
import Testing

@testable import TreewiseCore

/// Dates with month names in a pattern, in English, Dutch and German (ADR 0067).
@Suite struct MonthNameDateTests {
    private static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "text", kind: .text),
    ]
    private static let march14: [String: NameTemplate.Value] = [
        "date": .date(year: 2026, month: 3, day: 14), "text": .text("Report"),
    ]
    private static let march3: [String: NameTemplate.Value] = [
        "date": .date(year: 2026, month: 3, day: 3), "text": .text("Report"),
    ]

    private func template(_ text: String) throws -> NameTemplate {
        try NameTemplate.parse(text, fields: Self.fields).get()
    }

    @Test(arguments: [
        ("{date:d MMMM yyyy@en} {text}", "14 March 2026 Report"),
        ("{date:d MMMM yyyy@nl} {text}", "14 maart 2026 Report"),
        ("{date:d MMMM yyyy@de} {text}", "14 März 2026 Report"),
        ("{date:dd MMM yyyy@en} {text}", "14 Mar 2026 Report"),
        ("{date:dd MMM yyyy@nl} {text}", "14 mrt 2026 Report"),
        ("{date:dd MMM yyyy@de} {text}", "14 Mär 2026 Report"),
        ("{date:MMMM yyyy@nl} {text}", "maart 2026 Report"),
    ])
    func writesTheMonthsNameInTheLanguageOfThePattern(pattern: String, name: String) throws {
        #expect(try template(pattern).name(from: Self.march14) == name)
    }

    @Test func writesTheDayWithoutALeadingZero() throws {
        #expect(
            try template("{date:d MMMM yyyy@en} {text}").name(from: Self.march3)
                == "3 March 2026 Report")
    }

    @Test func aWordThatIsNoMonthDoesNotFit() throws {
        #expect(try !template("{date:d MMMM yyyy@en} {text}").matches("14 Marsh 2026 Report"))
    }

    @Test func aLanguageTreewiseDoesNotSpeakDoesNotParse() {
        let result = NameTemplate.parse("{date:d MMMM yyyy@fr} {text}", fields: Self.fields)
        guard case .failure(let problem) = result else {
            Issue.record("parsed")
            return
        }
        #expect(problem == .invalidFormat)
    }

    @Test(arguments: [
        (["nl-NL", "en"], MonthNames.Language.dutch),
        (["de"], MonthNames.Language.german),
        (["fr", "de"], MonthNames.Language.german),
        (["fr"], MonthNames.Language.english),
        ([], MonthNames.Language.english),
    ])
    func withoutALanguageWritesInTheAppsFirstLanguageItSpeaks(
        preferred: [String], language: MonthNames.Language
    ) {
        #expect(MonthNames.Language(preferring: preferred) == language)
    }

    @Test(arguments: [
        ("maart", Set([MonthNames.Language.dutch])),
        ("April", Set([MonthNames.Language.english, .german])),
        ("März", Set([MonthNames.Language.german])),
        ("Marsh", Set<MonthNames.Language>()),
    ])
    func tellsWhichLanguagesWriteAMonthsNameSo(name: String, languages: Set<MonthNames.Language>) {
        #expect(MonthNames.languages(writing: name) == languages)
    }
}
