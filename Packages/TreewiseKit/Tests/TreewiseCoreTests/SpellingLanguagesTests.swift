import Testing
import TreewiseCore

/// The languages a folder's name is spelled in (ADR 0139, rule 3): the user's own, from
/// Language & Region, each the spelling checker has a dictionary for.
@Suite struct SpellingLanguagesTests {
    /// The dictionaries the owner's Mac reported on 2026-11-20, with the spelling checker's
    /// own list of nearly every language, most of which accept any typo.
    private static let available = [
        "en_GB", "en", "en_AU", "en_IN", "en_SG", "en_ZA", "en_NZ", "en_CA", "en_PH", "en_JP",
        "nl", "de", "ar", "ars", "bg", "cs", "da", "el", "es", "fi", "fr", "ga", "he", "hi",
        "hu", "id", "is", "it", "ko", "lt", "nb", "nn", "pa", "pl", "pt_BR", "ro", "ru", "sl",
        "sv", "te", "tr", "uk", "vi",
    ]

    @Test func theUsersOwnLanguagesAreAskedAndNoOthers() {
        #expect(
            SpellingLanguages.chosen(preferred: ["en-NL", "nl-NL"], available: Self.available)
                == ["en", "nl"])
    }

    @Test(arguments: [
        ("en-GB", "en_GB"), ("pt-BR", "pt_BR"), ("de-DE", "de"), ("nl", "nl"),
    ])
    func aLanguageIsAskedByItsRegionFirst(preferred: String, asked: String) {
        #expect(
            SpellingLanguages.chosen(preferred: [preferred], available: Self.available) == [asked])
    }

    @Test func aLanguageWithoutADictionaryIsLeftOut() {
        #expect(
            SpellingLanguages.chosen(preferred: ["fy-NL", "nl-NL"], available: Self.available)
                == ["nl"])
    }

    @Test func aLanguageIsAskedOnce() {
        #expect(
            SpellingLanguages.chosen(preferred: ["nl-NL", "nl-BE"], available: Self.available)
                == ["nl"])
    }

    @Test func withoutAnyNoneIsAsked() {
        #expect(SpellingLanguages.chosen(preferred: ["fy-NL"], available: Self.available).isEmpty)
    }
}
