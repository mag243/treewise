import Testing
import TreewiseCore

/// A name that would fit but for a typo in its fixed text or the folder's name is
/// offered written right (ADR 0067).
@Suite struct NameTemplateNearlyFittingTests {
    private static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "text", kind: .text),
    ]

    private func corrected(
        _ template: String, _ name: String, folder: String = "Holiday 2026"
    ) throws -> String? {
        let parsed = try NameTemplate.parse(
            template, fields: Self.fields + NameTemplate.Field.suppliedByTreewise
        ).get()
        return parsed.correctedName(name, fixed: [NameTemplate.Field.folder.name: folder])
    }

    @Test func writesACutOffFolderNameRight() throws {
        #expect(
            try corrected("{date:yyyy.MM.dd} - {folder} - {text}", "2026.08.14 - Holiday 202 - c")
                == "2026.08.14 - Holiday 2026 - c")
    }

    @Test func writesATypoInFixedTextRight() throws {
        #expect(
            try corrected(
                "{date:yyyy.MM.dd} Belastingdienst - {text}", "2026.01.16 Belastngdienst - VAT")
                == "2026.01.16 Belastingdienst - VAT")
    }

    @Test func writesTheCaseOfFixedTextRight() throws {
        #expect(try corrected("{folder} {text}", "holiday 2026 Beach") == "Holiday 2026 Beach")
    }

    @Test func offersNothingForANameThatFits() throws {
        #expect(try corrected("{folder} - {text}", "Holiday 2026 - c") == nil)
    }

    @Test func offersNothingWhenTheTextIsNotNearlyThere() throws {
        #expect(try corrected("{folder} - {text}", "Holiday 2025 - c") == nil)
        #expect(try corrected("{folder} - {text}", "Notes - c") == nil)
    }

    @Test func offersNothingWhenAFieldDoesNotFit() throws {
        #expect(try corrected("{date:yyyy.MM.dd} - {folder} - {text}", "Holiday 202 - c") == nil)
    }

    @Test func readsAnOptionalPartThatIsLeftOut() throws {
        #expect(
            try corrected("{text}[ - Copy] - {folder}", "Beach - Holday 2026")
                == "Beach - Holiday 2026")
    }

    @Test func readsTheFittingPartOfAChoiceOfParts() throws {
        #expect(
            try corrected(
                "Tax - <Sales {year}.Q{seq:4}|Payroll {year}.{seq:12}>", "Tax - Salez 2025.Q3")
                == "Tax - Sales 2025.Q3")
    }

    @Test func takesTheWholeFolderNameBeforeACutOffOne() throws {
        #expect(
            try corrected("{folder} {text}", "holiday 2026 Beach Day") == "Holiday 2026 Beach Day")
        #expect(try corrected("{folder} {text}", "Holiday Beach Day") == "Holiday 2026 Beach Day")
    }
}
