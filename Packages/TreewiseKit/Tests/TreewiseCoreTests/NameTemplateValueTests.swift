import Testing
import TreewiseCore

/// Values from an add-on are data from another process, so a date in one must be a real
/// day before Treewise writes it (ADR 0057).
@Suite struct NameTemplateValueTests {
    @Test func textIsWellFormed() {
        #expect(NameTemplate.Value.text("Acme").isWellFormed)
    }

    @Test func aRealDayIsWellFormed() {
        #expect(NameTemplate.Value.date(year: 2028, month: 2, day: 29).isWellFormed)
    }

    @Test(arguments: [
        (2026, 13, 1), (2026, 0, 1), (2026, 2, 30), (2026, 4, 31), (2026, 1, 0), (0, 1, 1),
        (10_000, 1, 1),
    ])
    func aDayThatDoesNotExistIsNot(year: Int, month: Int, day: Int) {
        #expect(!NameTemplate.Value.date(year: year, month: month, day: day).isWellFormed)
    }
}
