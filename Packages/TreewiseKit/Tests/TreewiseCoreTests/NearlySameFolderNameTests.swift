import Testing
import TreewiseCore

/// Telling a folder whose name is nearly another's, as a spelling error in a year before
/// (ADR 0139).
@Suite struct NearlySameFolderNameTests {
    /// A spelling checker that knows only these words.
    private static func knows(_ words: Set<String>) -> @Sendable (String) -> Bool {
        { words.contains($0) }
    }

    @Test(arguments: [
        // The same but for case, spaces, `-`, `_` or diacritics.
        ("Belasting Dienst", "belastingdienst", true),
        ("Cafe", "Café", true),
        ("Q1-Stukken", "Q1 stukken", true),
        ("Jaar_overzicht", "Jaaroverzicht", true),
        // Other digits are another folder.
        ("2025", "2026", false),
        ("Q1", "Q2", false),
        ("Factuur 3", "Factuur 4", false),
        ("Kwartaal 1", "Kwartaal 2", false),
        // Typos, as NearlySameText counts them.
        ("Belastingsdienst", "Belastingdienst", true),
        ("Corespondentie", "Correspondentie", true),
        ("Fatcuur", "Factuur", true),
        ("Bonnen", "Bonen", true),
        // Too short or too far apart.
        ("Huur", "Huis", false),
        ("Inkoop", "Verkoop", false),
        ("Facturen", "Factuur", false),
        // A cut-off start is likely another folder.
        ("Belasting", "Belastingdienst", false),
    ])
    func tellsWhetherNamesAreNearlyTheSame(_ one: String, _ other: String, _ nearly: Bool) {
        let speller = Self.knows([])
        #expect(NearlySameFolderName.matches(one, other, isSpelledCorrectly: speller) == nearly)
        #expect(NearlySameFolderName.matches(other, one, isSpelledCorrectly: speller) == nearly)
    }

    @Test func twoCorrectlySpelledWordsAreTwoFolders() {
        let speller = Self.knows(["Bonnen", "Bonen"])
        #expect(!NearlySameFolderName.matches("Bonnen", "Bonen", isSpelledCorrectly: speller))
    }

    @Test func oneMisspelledNameIsNearlyTheOther() {
        let speller = Self.knows(["Belastingdienst"])
        #expect(
            NearlySameFolderName.matches(
                "Belastingsdienst", "Belastingdienst", isSpelledCorrectly: speller))
    }

    @Test func namesTheSameButForSpacesMatchEvenWhenBothAreWords() {
        let speller = Self.knows(["Belasting Dienst", "Belastingdienst"])
        #expect(
            NearlySameFolderName.matches(
                "Belasting Dienst", "Belastingdienst", isSpelledCorrectly: speller))
    }
}
