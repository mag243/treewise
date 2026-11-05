import Testing
import TreewiseCore
import TreewiseModuleInterface

/// Helpers that find what is general in a text, for modules (ADR 0057).
@Suite struct TextScannerTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> NameTemplate.Value {
        .date(year: year, month: month, day: day)
    }

    @Test(arguments: [
        ("Date 02-11-2026.", 2026, 11, 2),
        ("2026-11-02", 2026, 11, 2),
        ("on 2.11.2026", 2026, 11, 2),
        ("2/11/2026", 2026, 11, 2),
        ("2 Nov 2026", 2026, 11, 2),
        ("2 november 2026", 2026, 11, 2),
        ("2. März 2026", 2026, 3, 2),
        ("14 oktober 2026", 2026, 10, 14),
        ("31 mei 2026", 2026, 5, 31),
    ])
    func findsADate(_ text: String, _ year: Int, _ month: Int, _ day: Int) {
        #expect(TextScanner.dates(in: text) == [date(year, month, day)])
    }

    @Test func findsDatesInOrder() {
        #expect(
            TextScanner.dates(in: "Sent 01-10-2026, due 2 Nov 2026")
                == [date(2026, 10, 1), date(2026, 11, 2)])
    }

    @Test(arguments: [
        "32-11-2026", "02-13-2026", "31-02-2026", "F26009", "1234567890", "12 apples 2026",
    ])
    func findsNoDateIn(_ text: String) {
        #expect(TextScanner.dates(in: text).isEmpty)
    }

    @Test(arguments: [
        ("Total € 1.234,56", "1234.56"),
        ("Total €1,234.56", "1234.56"),
        ("EUR 99,00", "99.00"),
        ("12.50 EUR", "12.50"),
        ("$ 7.5", "7.50"),
    ])
    func findsAnAmount(_ text: String, _ amount: String) {
        #expect(TextScanner.amounts(in: text) == [amount])
    }

    @Test(arguments: ["Invoice 1234", "2026.11.02", "12,50"])
    func findsNoAmountWithoutACurrency(_ text: String) {
        #expect(TextScanner.amounts(in: text).isEmpty)
    }
}
