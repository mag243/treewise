import Testing
import TreewiseCore

/// Telling a typo or a cut-off from other text, for a name that nearly fits (ADR 0067).
@Suite struct NearlySameTextTests {
    @Test(arguments: [
        ("Holiday 2026", "Holiday 2026", true),
        ("holiday 2026", "Holiday 2026", true),
        // One or two characters added, removed or replaced, from 10 characters on.
        ("Holliday 2026", "Holiday 2026", true),
        ("Hloiday 2026", "Holiday 2026", true),
        ("Hollidday 2026", "Holiday 2026", true),
        ("Hollliddday 2026", "Holiday 2026", false),
        // One below 10 characters, none below 5.
        ("Invoce", "Invoice", true),
        ("Inovce", "Invoice", false),
        ("Tag", "Tax", false),
        // A different digit is no typo.
        ("Holiday 2025", "Holiday 2026", false),
        ("Holiday 20266", "Holiday 2026", false),
        // The start, ending where a word ends or with at most two characters missing.
        ("Holiday", "Holiday 2026", true),
        ("Holiday 202", "Holiday 2026", true),
        ("Holiday 20", "Holiday 2026", true),
        ("Holiday 2", "Holiday 2026", false),
        ("Holi", "Holiday 2026", false),
        ("Hol", "Holiday", false),
        ("Belastngdienst", "Belastingdienst", true),
        ("Notes", "Holiday 2026", false),
    ])
    func tellsWhetherTextIsNearlyTheSame(_ text: String, _ expected: String, _ nearly: Bool) {
        #expect(NearlySameText.matches(text, expected) == nearly)
    }
}
