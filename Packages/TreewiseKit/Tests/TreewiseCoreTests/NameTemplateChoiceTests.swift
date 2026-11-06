import Foundation
import Testing
import TreewiseCore

/// A field that names alternatives, like `{number|company}` (ADR 0063).
@Suite struct NameTemplateChoiceTests {
    private static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "company", kind: .text),
        NameTemplate.Field(name: "number", kind: .number),
        NameTemplate.Field(name: "description", kind: .text),
    ]

    private func template(_ text: String) throws -> NameTemplate {
        try NameTemplate.parse(text, fields: Self.fields).get()
    }

    private func problem(_ text: String) -> NameTemplate.Problem? {
        if case .failure(let problem) = NameTemplate.parse(text, fields: Self.fields) {
            return problem
        }
        return nil
    }

    @Test func writesTheFirstAlternativeWithAValue() throws {
        let template = try template("Invoice {number|company}")
        #expect(
            template.name(from: ["number": .text("F26009"), "company": .text("Northwind")])
                == "Invoice F26009")
        #expect(template.name(from: ["company": .text("Northwind")]) == "Invoice Northwind")
    }

    @Test func leavesAGapWhenNoAlternativeHasAValue() throws {
        let name = try template("{description} {number|company}")
            .name(from: ["description": .text("Cables")])
        #expect(name == "Cables \(NameTemplate.gap)")
    }

    @Test func anOptionalChoiceWithoutAValueFallsAway() throws {
        let name = try template("{description}[ - {number|company}]")
            .name(from: ["description": .text("Cables")])
        #expect(name == "Cables")
    }

    @Test func writesADateAlternativeInItsFormat() throws {
        let name = try template("{date:dd-MM-yy|number} Scan")
            .name(from: ["date": .date(year: 2026, month: 11, day: 2)])
        #expect(name == "02-11-26 Scan")
    }

    @Test(arguments: ["2026.11.02 Scan", "F26009 Scan"])
    func recognizesANameThatFitsAnyAlternative(_ name: String) throws {
        #expect(try template("{date:yyyy.MM.dd|number} Scan").matches(name))
    }

    @Test func recognizesNoNameThatFitsNoAlternative() throws {
        #expect(try !template("{date:yyyy.MM.dd|number} Scan").matches("Holiday Scan"))
    }

    @Test func findsTheDateInAChoice() throws {
        let date = try template("{date:yyyy.MM.dd|number} Scan").date(in: "2026.11.02 Scan")
        #expect(date == .date(year: 2026, month: 11, day: 2))
    }

    @Test func refusesAnEmptyAlternative() {
        #expect(problem("{number|}") == .unbalancedBraces)
        #expect(problem("{|number}") == .unbalancedBraces)
    }

    @Test func refusesAnUnknownAlternative() {
        #expect(problem("{number|supplier}") == .unknownField("supplier"))
    }

    @Test func refusesAFormatOnAnAlternativeThatIsNoDate() {
        #expect(problem("{date|number:yyyy}") == .invalidFormat)
    }

    @Test func keepsABarOutsideBracesAsText() throws {
        #expect(
            try template("{number} | {company}").name(from: [
                "number": .text("F26009"), "company": .text("Northwind"),
            ]) == "F26009 | Northwind")
    }
}
