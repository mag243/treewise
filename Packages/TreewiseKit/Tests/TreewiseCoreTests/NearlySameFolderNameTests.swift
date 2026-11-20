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

    // MARK: The years' history (rule 5)

    private static func history(_ years: [Int: [String]]) -> FolderNameHistory {
        FolderNameHistory(years)
    }

    @Test func namesSideBySideInAYearAreTwoFolders() {
        let history = Self.history([2024: ["Belasting Dienst", "Belastingdienst"]])
        #expect(
            !NearlySameFolderName.matches(
                "Belasting Dienst", "Belastingdienst", isSpelledCorrectly: Self.knows([]),
                history: history))
    }

    @Test(arguments: [("Huur", "Huis"), ("Bonen", "Bonnen")])
    func aNameInOneYearIsNearlyTheNameInMoreYears(_ rare: String, _ usual: String) {
        let history = Self.history([
            2021: [usual], 2022: [usual], 2023: [usual], 2024: [usual], 2025: [rare],
            2026: [usual],
        ])
        let speller = Self.knows([rare, usual])
        #expect(
            NearlySameFolderName.matches(rare, usual, isSpelledCorrectly: speller, history: history)
        )
    }

    @Test(arguments: [("Huis", "Auto"), ("Q1", "Q2"), ("Bank", "Belasting")])
    func historyGivesNoLikenessToNamesUnlikeEachOther(_ rare: String, _ usual: String) {
        let history = Self.history([2024: [usual], 2025: [usual], 2026: [rare]])
        #expect(
            !NearlySameFolderName.matches(
                rare, usual, isSpelledCorrectly: Self.knows([]), history: history))
    }

    @Test func namesInAsManyYearsKeepTheOtherRules() {
        let history = Self.history([2025: ["Huur"], 2026: ["Huis"]])
        #expect(
            !NearlySameFolderName.matches(
                "Huur", "Huis", isSpelledCorrectly: Self.knows([]), history: history))
    }

    @Test func historyCountsYearsByTheNameAsTheFileSystemCompares() {
        let history = Self.history([2024: ["huis"], 2025: ["Huis"], 2026: ["Huur"]])
        #expect(history.years(of: "HUIS") == [2024, 2025])
    }
}
