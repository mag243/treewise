import Testing
import TreewiseCore

/// Where a template's fields sit in a name, to mark them while the user edits it.
@Suite struct NameTemplateFieldRangesTests {
    private static let fields =
        [
            NameTemplate.Field(name: "date", kind: .date),
            NameTemplate.Field(name: "text", kind: .text),
            NameTemplate.Field(name: "number", kind: .number),
        ] + NameTemplate.Field.suppliedByTreewise

    private func marked(_ template: String, _ name: String, folder: String = "Tax") throws
        -> [String]
    {
        let parsed = try NameTemplate.parse(template, fields: Self.fields).get()
        return parsed.fieldRanges(in: name, fixed: ["folder": folder]).map { String(name[$0]) }
    }

    @Test func marksTheFieldsAndNotTheFixedText() throws {
        let marks = try marked(
            "{date:yyyy.MM.dd} Tax - <Sales {year}.Q{seq:4}|{text}>",
            "2026.01.31 Tax - Sales 2025.Q4")
        #expect(marks == ["2026.01.31", "2025", "4"])
    }

    @Test func leavesTheFolderUnmarked() throws {
        #expect(try marked("{folder} {text}", "Tax Letter") == ["Letter"])
    }

    @Test func marksTheAlternativeThatWasWritten() throws {
        #expect(try marked("Invoice {number|text}", "Invoice F26009") == ["F26009"])
    }

    @Test func marksNothingInANameThatDoesNotFit() throws {
        #expect(try marked("Invoice {number}", "Holiday") == [])
    }
}
