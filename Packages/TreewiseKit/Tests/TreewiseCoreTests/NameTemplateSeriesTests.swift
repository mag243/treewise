import Foundation
import Testing
import TreewiseCore

/// `{seq}` with a range, a list or an open end, and names that fit only with a number the
/// series can give (ADR 0089).
@Suite struct NameTemplateSeriesTests {
    private static let fields =
        [NameTemplate.Field(name: "text", kind: .text)] + NameTemplate.Field.suppliedByTreewise

    private func template(_ text: String) throws -> NameTemplate {
        try NameTemplate.parse(text, fields: Self.fields).get()
    }

    private func problem(_ text: String) -> NameTemplate.Problem? {
        if case .failure(let problem) = NameTemplate.parse(text, fields: Self.fields) {
            return problem
        }
        return nil
    }

    private func next(_ text: String, after siblings: [String] = [], year: Int? = 2026) throws
        -> String?
    {
        try template(text).names(
            from: [:], context: .init(siblingNames: siblings, currentName: "scan", fileYear: year)
        ).first?.name
    }

    // MARK: Reading

    @Test(arguments: [
        "{seq}", "{seq:4}", "{seq:1-4}", "{seq:2-4}", "{seq:0-3}", "{seq:2,4,6,8}", "{seq:5-}",
        "{seq:0-}", "{seq:1,10,100}",
    ])
    func readsASeries(_ series: String) {
        #expect(problem("R \(series)") == nil)
    }

    @Test(arguments: [
        "{seq:1}", "{seq:0}", "{seq:x}", "{seq:4-2}", "{seq:3-3}", "{seq:-4}", "{seq:1-4-6}",
        "{seq:a-b}", "{seq:2,2}", "{seq:4,2}", "{seq:2,}", "{seq:,2}", "{seq:2,4-6}",
        "{seq:-}", "{seq:}",
    ])
    func refusesWhatIsNoSeries(_ series: String) {
        #expect(problem("R \(series)") == .invalidFormat)
    }

    // MARK: The first number of a series without names

    @Test(arguments: [
        ("R {seq}", "R 1"), ("R {seq:4}", "R 1"), ("R {seq:1-4}", "R 1"), ("R {seq:2-4}", "R 2"),
        ("R {seq:0-3}", "R 0"), ("R {seq:2,4,6,8}", "R 2"), ("R {seq:5-}", "R 5"),
        ("R {seq:12}", "R 01"), ("R {seq:1-12}", "R 01"), ("R {seq:2,4,10}", "R 02"),
    ])
    func startsAtItsFirstNumberInTheWidthOfItsHighest(_ text: String, _ first: String) throws {
        #expect(try next(text) == first)
    }

    // MARK: The next number

    @Test(arguments: [
        ("R {year}.Q{seq:2-4}", ["R 2026.Q3"], "R 2026.Q4"),
        ("R {year}.Q{seq:2-4}", ["R 2026.Q4"], "R 2027.Q2"),
        ("R {year}.{seq:2,4,6,8}", ["R 2026.4"], "R 2026.6"),
        ("R {year}.{seq:2,4,6,8}", ["R 2026.8", "R 2026.6"], "R 2027.2"),
        ("R {seq:5-}", ["R 7"], "R 8"),
        ("R {seq:2,4,6,8}", ["R 8"], "R 2"),
        ("R {year}.{seq:1-12}", ["R 2026.12"], "R 2027.01"),
        ("R {year}.{seq:4}", ["R 2026.4"], "R 2027.1"),
    ])
    func continuesTheSeries(_ text: String, _ siblings: [String], _ expected: String) throws {
        #expect(try next(text, after: siblings) == expected)
    }

    // MARK: Recognizing

    @Test(arguments: [
        ("Q{seq:4}", "Q1", true), ("Q{seq:4}", "Q4", true), ("Q{seq:4}", "Q5", false),
        ("Q{seq:4}", "Q0", false), ("Q{seq:2-4}", "Q1", false), ("Q{seq:2-4}", "Q3", true),
        ("R {seq:2,4,6,8}", "R 6", true), ("R {seq:2,4,6,8}", "R 3", false),
        ("R {seq:5-}", "R 4", false), ("R {seq:5-}", "R 5", true), ("R {seq:5-}", "R 123", true),
        ("R {seq:12}", "R 07", true), ("R {seq:12}", "R 7", true), ("R {seq:12}", "R 13", false),
        ("R {seq:1-120}", "R 99", true), ("R {seq:1-120}", "R 120", true),
        ("R {seq:1-120}", "R 121", false), ("R {seq:95-1005}", "R 100", true),
        ("R {seq:95-1005}", "R 94", false), ("R {seq:95-1005}", "R 1006", false),
        ("R {seq:0-3}", "R 0", true), ("R {seq}", "R 42", true), ("R {seq}", "R 0", false),
    ])
    func fitsOnlyANumberTheSeriesCanGive(_ text: String, _ name: String, _ fits: Bool) throws {
        #expect(try template(text).matches(name) == fits)
    }

    @Test func continuesOnlyFromNamesThatFit() throws {
        #expect(try next("R {seq:2-4}", after: ["R 3", "R 9"]) == "R 4")
    }
}
