import Testing
import TreewiseCore

/// Which part of a name each field of a template filled in, and where the fields sit in a
/// template's text, so both can share a colour per field.
@Suite struct NameTemplateFieldMarksTests {
    private static let fields =
        [
            NameTemplate.Field(name: "date", kind: .date),
            NameTemplate.Field(name: "text", kind: .text),
            NameTemplate.Field(name: "number", kind: .number),
            NameTemplate.Field(name: "company", kind: .text),
        ] + NameTemplate.Field.suppliedByTreewise

    private func marked(_ template: String, _ name: String, folder: String = "Tax") throws
        -> [String]
    {
        let parsed = try NameTemplate.parse(template, fields: Self.fields).get()
        return parsed.fieldMarks(in: name, fixed: ["folder": folder]).map {
            "\($0.key)=\(name[$0.range])"
        }
    }

    @Test func marksEachFieldWithItsKeyAndNotTheFixedText() throws {
        let marks = try marked(
            "{date:yyyy.MM.dd} Tax - <Sales {year}.Q{seq:4}|{text}>",
            "2026.01.31 Tax - Sales 2025.Q4")
        #expect(marks == ["date=2026.01.31", "year=2025", "seq=4"])
    }

    @Test func marksTheFolderLikeAnyField() throws {
        #expect(try marked("{folder} {text}", "Tax Letter") == ["folder=Tax", "text=Letter"])
    }

    @Test func aChoiceOfFieldsIsOneKeyWhicheverWasWritten() throws {
        #expect(try marked("Invoice {number|company}", "Invoice F26009") == ["number=F26009"])
        #expect(try marked("Invoice {number|company}", "Invoice Northwind") == ["number=Northwind"])
    }

    @Test func marksAGapAsItsField() throws {
        #expect(
            try marked("{text} {number}", "Letter \(NameTemplate.gap)")
                == ["text=Letter", "number=\(NameTemplate.gap)"])
    }

    @Test func marksNothingInANameThatDoesNotFit() throws {
        #expect(try marked("Invoice {number}", "Holiday") == [])
    }

    @Test func findsTheFieldsInTheTextOfATemplate() {
        let text = "{date:yyyy.MM.dd} {folder} <Sales {year}|{number|company}> {year}"
        let tokens = NameTemplate.fieldTokens(in: text)
        #expect(tokens.map(\.key) == ["date", "folder", "year", "number", "year"])
        #expect(
            tokens.map { String(text[$0.range]) } == [
                "{date:yyyy.MM.dd}", "{folder}", "{year}", "{number|company}", "{year}",
            ])
    }

    @Test func ordersTheKeysByTheirFirstPlace() {
        #expect(
            NameTemplate.fieldOrder(in: "{year} {seq} {year} {text}") == ["year", "seq", "text"])
    }

    @Test func readsTheFieldsOfATemplateBeingTyped() {
        // An unfinished field is no field yet.
        #expect(NameTemplate.fieldTokens(in: "{text} - {num").map(\.key) == ["text"])
    }
}
