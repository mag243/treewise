import Foundation
import Testing
import TreewiseCore

/// `{year:yy}`, `{folder:N}`, and `:lower`, `:upper` and `:title` on text fields (ADR 0089).
@Suite struct NameTemplateModifierTests {
    private static let fields =
        [
            NameTemplate.Field(name: "date", kind: .date),
            NameTemplate.Field(name: "text", kind: .text),
            NameTemplate.Field(name: "company", kind: .text),
            NameTemplate.Field(name: "number", kind: .number),
        ] + NameTemplate.Field.suppliedByTreewise

    private func template(_ text: String) throws -> NameTemplate {
        try NameTemplate.parse(text, fields: Self.fields).get()
    }

    private func problem(_ text: String) -> NameTemplate.Problem? {
        if case .failure(let problem) = NameTemplate.parse(text, fields: Self.fields) {
            return problem
        }
        return nil
    }

    private func name(
        _ text: String, _ values: [String: NameTemplate.Value], siblings: [String] = [],
        year: Int? = 2026
    ) throws -> String? {
        try template(text).names(
            from: values,
            context: .init(siblingNames: siblings, currentName: "scan", fileYear: year)
        ).first?.name
    }

    // MARK: Reading

    @Test(arguments: [
        "{year:yy}", "{folder:1}", "{folder:2}", "{text:lower}", "{text:upper}", "{text:title}",
        "{company:upper}", "{number:lower}", "{number|company:title}",
    ])
    func readsAModifier(_ field: String) {
        #expect(problem("R \(field)") == nil)
    }

    @Test(arguments: [
        "{year:yyyy}", "{year:y}", "{folder:0}", "{folder:x}", "{folder:-1}", "{text:shout}",
        "{text:}", "{date:lower}", "{text:yy}", "{year:upper}",
    ])
    func refusesAModifierTheFieldDoesNotTake(_ field: String) {
        #expect(problem("R \(field)") == .invalidFormat)
    }

    // MARK: Two-digit years

    @Test func writesTheYearInTwoDigits() throws {
        #expect(try name("F{year:yy}", [:]) == "F26")
    }

    @Test(arguments: [("F26", true), ("F2026", false), ("F6", false)])
    func recognizesATwoDigitYear(_ text: String, _ fits: Bool) throws {
        #expect(try template("F{year:yy}").matches(text) == fits)
    }

    @Test func continuesASeriesAcrossTwoDigitYears() throws {
        #expect(try name("R {year:yy}.Q{seq:4}", [:], siblings: ["R 26.Q4"]) == "R 27.Q1")
        #expect(try name("R {year:yy}.Q{seq:4}", [:], siblings: ["R 26.Q2"]) == "R 26.Q3")
    }

    // MARK: Folders higher up

    @Test func writesTheFolderSoManyLevelsUp() throws {
        let values: [String: NameTemplate.Value] = [
            "folder": .text("2026"), "folder:2": .text("Client"), "text": .text("Invoice"),
        ]
        #expect(try name("{folder:2} {folder:1} {text}", values) == "Client 2026 Invoice")
    }

    @Test func aFolderThatIsNotThereLeavesItsOptionalPartOut() throws {
        let values: [String: NameTemplate.Value] = ["folder": .text("Top"), "text": .text("A")]
        #expect(try name("[{folder:2} ]{text}", values) == "A")
    }

    @Test func recognizesTheFolderSoManyLevelsUp() throws {
        let fixed = ["folder": "2026", "folder:2": "Client"]
        #expect(try template("{folder:2} {text}").matches("Client Invoice", fixed: fixed))
        #expect(try !template("{folder:2} {text}").matches("2026 Invoice", fixed: fixed))
    }

    // MARK: The case of text

    @Test(arguments: [
        ("{text:lower}", "Late Filing NOTICE", "late filing notice"),
        ("{text:upper}", "Late filing notice", "LATE FILING NOTICE"),
        ("{text:title}", "VAT return for q3", "VAT Return For Q3"),
        ("{company:upper}", "Tax Office", "TAX OFFICE"),
        ("{number:lower}", "F26ABC", "f26abc"),
    ])
    func writesTextInItsCase(_ text: String, _ value: String, _ written: String) throws {
        let field = text.dropFirst().prefix { $0 != ":" }
        #expect(try name(text, [String(field): .text(value)]) == written)
    }

    @Test(arguments: [
        ("{text:lower}", "late notice", true), ("{text:lower}", "Late notice", false),
        ("{text:upper}", "LATE NOTICE 3", true), ("{text:upper}", "LATE Notice", false),
        ("{text:title}", "Late Notice", true), ("{text:title}", "VAT Return 3", true),
        ("{text:title}", "Late notice", false), ("{number:upper}", "F26ABC", true),
        ("{number:upper}", "F26abc", false),
    ])
    func fitsOnlyTextInItsCase(_ text: String, _ written: String, _ fits: Bool) throws {
        #expect(try template(text).matches(written) == fits)
    }
}
