import Foundation
import Testing
import TreewiseCore

/// A pattern both makes a name and recognizes one (ADR 0057).
@Suite struct NameTemplateTests {
    private static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "company", kind: .text),
        NameTemplate.Field(name: "number", kind: .number),
        NameTemplate.Field(name: "description", kind: .text),
    ]
    private static let values: [String: NameTemplate.Value] = [
        "date": .date(year: 2026, month: 11, day: 2), "company": .text("Northwind"),
        "number": .text("F26009"), "description": .text("Cables"),
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

    @Test func makesANameFromValues() throws {
        let name = try template("{date:yyyy.MM.dd} {company} - {number} - {description}")
            .name(from: Self.values)
        #expect(name == "2026.11.02 Northwind - F26009 - Cables")
    }

    @Test func writesADateInItsFormat() throws {
        #expect(try template("{date:dd-MM-yy}").name(from: Self.values) == "02-11-26")
        #expect(try template("{date}").name(from: Self.values) == "2026-11-02")
    }

    @Test func keepsAnOptionalPartWithItsValue() throws {
        #expect(
            try template("{number}[ - {description}]").name(from: Self.values) == "F26009 - Cables")
    }

    @Test func dropsAnOptionalPartWithoutItsValue() throws {
        let values = Self.values.filter { $0.key != "description" }
        #expect(try template("{number}[ - {description}]").name(from: values) == "F26009")
    }

    @Test func treatsAnEmptyValueAsNone() throws {
        var values = Self.values
        values["description"] = .text("  ")
        #expect(try template("{number}[ - {description}]").name(from: values) == "F26009")
    }

    @Test func leavesAGapForARequiredValue() throws {
        let values = Self.values.filter { $0.key != "number" }
        #expect(
            try template("{company} - {number}").name(from: values)
                == "Northwind - " + NameTemplate.gap)
    }

    @Test func leavesAGapForADateThatIsNoDate() throws {
        var values = Self.values
        values["date"] = .text("soon")
        #expect(
            try template("{date} {company}").name(from: values) == NameTemplate.gap + " Northwind")
    }

    @Test func givesNoNameWithoutAnyValue() throws {
        #expect(try template("{company} - {number}").name(from: [:]) == nil)
    }

    @Test func aFixedFieldAloneIsNoValue() throws {
        let template = try NameTemplate.parse("{folder} {number}", fields: Self.fields + [.folder])
            .get()
        #expect(template.name(from: ["folder": .text("Invoices")]) == nil)
    }

    @Test func makesNamesWithSingleSpaces() throws {
        var values = Self.values
        values["company"] = .text("North  wind")
        #expect(try template("{number}  {company}").name(from: values) == "F26009 North wind")
    }

    @Test(arguments: ["F1  - x", " F1 - x", "F1 - x "])
    func aNameWithStraySpacesDoesNotFit(_ name: String) throws {
        #expect(try !template("{number} - {description}").matches(name))
    }

    @Test(arguments: [
        ("{date:yyyy.MM.dd} {company}", "2026.11.02 Northwind", true),
        ("{date:yyyy.MM.dd} {company}", "2026-11-02 Northwind", false),
        ("{date:yyyy.MM.dd} {company}", "Northwind", false),
        ("{number}", "F26009", true),
        ("{number}", "8841", true),
        ("{number}", "no digits", false),
        ("{number}", "3851E", true),
        ("{number}", "262390v1", true),
        ("{number}", "26AF142", true),
        ("{number}", "26G0320014-1", true),
        ("{number}", "JK:o:26049", true),
        ("{number}", "two 12", false),
        ("Scan {number}", "Scan 12", true),
        ("Scan {number}", "Scan.12", false),
        ("a.b {number}", "axb 1", false),
        ("{number}[ - {description}]", "F1", true),
        ("{number}[ - {description}]", "F1 - Cables", true),
        ("{number}[ - {description}]", "F1 - ", false),
        ("{company} - {number}", "Harbor - Print - 12", true),
    ])
    func recognizesANameOrNot(_ text: String, _ name: String, _ fits: Bool) throws {
        #expect(try template(text).matches(name) == fits)
    }

    @Test func recognizesWhatItMakes() throws {
        let template = try template("{date:yyyy.MM.dd} {company} - {number}[ - {description}]")
        #expect(template.matches(try #require(template.name(from: Self.values))))
    }

    /// A name is made with single spaces and none at its ends, so a pattern with a stray
    /// space has to recognize it all the same, or every name it makes is proposed again.
    @Test(arguments: [
        "{date:yyyy.MM.dd} - {company} - {description} ",
        " {date:yyyy.MM.dd} - {company} - {description}",
        "{date:yyyy.MM.dd}  -  {company} - {description}",
    ])
    func recognizesWhatItMakesDespiteStraySpaces(_ text: String) throws {
        let template = try template(text)
        let name = try #require(template.name(from: Self.values))
        #expect(name == "2026.11.02 - Northwind - Cables")
        #expect(template.matches(name))
    }

    @Test func comparesFixedTextAsWritten() throws {
        #expect(try !template("Scan {number}").matches("scan 12"))
    }

    @Test(arguments: ["", "   ", "[{number}]"])
    func refusesATemplateWithNothingRequired(_ text: String) {
        #expect(problem(text) == .nothingRequired)
    }

    @Test(arguments: ["{number", "number}", "{}", "{ number}"])
    func refusesBadBraces(_ text: String) {
        #expect(problem(text) == .unbalancedBraces)
    }

    @Test(arguments: ["{number}[ - {company}", "{number}] - {company}"])
    func refusesBadBrackets(_ text: String) {
        #expect(problem(text) == .unbalancedBrackets)
    }

    @Test func refusesNestedOptionalParts() {
        #expect(problem("{number}[a[{company}]]") == .nestedOptionalParts)
    }

    @Test func refusesAnUnknownField() {
        #expect(problem("{price}") == .unknownField("price"))
    }

    @Test(arguments: ["a:b {number}", "{number}[:{company}]"])
    func refusesAColon(_ text: String) {
        #expect(problem(text) == .containsPathSeparator)
    }

    @Test func allowsASlashAsFinderDoes() throws {
        let template = try template("Ref/{number}")
        #expect(template.name(from: Self.values) == "Ref/F26009")
        #expect(template.matches("Ref/F26009"))
    }

    @Test(arguments: ["{date:hh}", "{date:yyyy/MM}", "{company:yyyy}"])
    func refusesABadFormat(_ text: String) {
        #expect(problem(text) == .invalidFormat)
    }

    @Test func fillsInTheFolderName() throws {
        let template = try NameTemplate.parse("{folder} {number}", fields: Self.fields + [.folder])
            .get()
        var values = Self.values
        values[NameTemplate.Field.folder.name] = .text("Invoices")
        #expect(template.name(from: values) == "Invoices F26009")
    }

    @Test func recognizesOnlyItsOwnFolderName() throws {
        let template = try NameTemplate.parse("{folder} {number}", fields: Self.fields + [.folder])
            .get()
        let folder = [NameTemplate.Field.folder.name: "Invoices"]
        #expect(template.matches("Invoices 12", fixed: folder))
        #expect(!template.matches("Contracts 12", fixed: folder))
        #expect(!template.matches("invoices 12", fixed: folder))
    }

    @Test func treatsAFolderNameAsPlainText() throws {
        let template = try NameTemplate.parse("{folder} {number}", fields: Self.fields + [.folder])
            .get()
        let folder = [NameTemplate.Field.folder.name: "A.B (2)"]
        #expect(template.matches("A.B (2) 12", fixed: folder))
        #expect(!template.matches("AxB (2) 12", fixed: folder))
    }

    @Test func recognizesNothingWithoutAFixedValue() throws {
        let template = try NameTemplate.parse("{folder} {number}", fields: Self.fields + [.folder])
            .get()
        #expect(!template.matches("Invoices 12"))
    }

    @Test func aFolderFieldTakesNoFormat() {
        #expect(
            NameTemplate.parse("{folder:yyyy}", fields: [.folder]) == .failure(.invalidFormat))
    }

    @Test(arguments: [
        ("{date:yyyy.MM.dd} {company}", "2026.11.02 Northwind", 2026, 11, 2),
        ("x {date:dd-MM-yy}", "x 02-11-26", 2026, 11, 2),
        ("{date}[ - {company}]", "2026-11-02", 2026, 11, 2),
    ])
    func readsTheDateInAName(_ text: String, _ name: String, _ year: Int, _ month: Int, _ day: Int)
        throws
    {
        #expect(try template(text).date(in: name) == .date(year: year, month: month, day: day))
    }

    @Test func readsNoDateWhereThereIsNone() throws {
        #expect(try template("{date} {company}").date(in: "Northwind") == nil)
        #expect(try template("{company}").date(in: "Northwind") == nil)
    }

    @Test func givesBackItsText() throws {
        let text = "{date:yyyy.MM.dd} {company}[ - {number}]"
        #expect(try template(text).text == text)
    }

    @Test func aValueSurvivesEncoding() throws {
        let data = try JSONEncoder().encode(Self.values)
        #expect(
            try JSONDecoder().decode([String: NameTemplate.Value].self, from: data) == Self.values)
    }
}
