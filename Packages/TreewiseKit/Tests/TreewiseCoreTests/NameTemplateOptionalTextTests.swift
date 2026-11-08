import Foundation
import Testing
import TreewiseCore

/// An optional part of fixed text only, written when the current name holds its text
/// (ADR 0064, addition of 2026-11-08).
@Suite struct NameTemplateOptionalTextTests {
    private static let fields =
        [NameTemplate.Field(name: "text", kind: .text)] + NameTemplate.Field.suppliedByTreewise
    private static let payroll = "Payroll {year}.{seq:12}[ correction]"
    private static let series = ["Payroll 2026.01", "Payroll 2026.02"]

    private func name(_ text: String, current: String, siblings: [String] = []) throws
        -> String?
    {
        try NameTemplate.parse(text, fields: Self.fields).get().names(
            from: ["text": .text("Letter")],
            context: .init(siblingNames: siblings, currentName: current, fileYear: 2026)
        ).first?.name
    }

    @Test func leavesTheTextOutWhenTheCurrentNameLacksIt() throws {
        #expect(
            try name(Self.payroll, current: "scan", siblings: Self.series) == "Payroll 2026.03")
    }

    @Test(arguments: [
        "scan correction", "Correction payroll", "CORRECTION", "scan-correction-feb",
        "scan corrêction",
    ])
    func writesTheTextWhenTheCurrentNameHoldsIt(_ current: String) throws {
        #expect(
            try name(Self.payroll, current: current, siblings: Self.series)
                == "Payroll 2026.03 correction")
    }

    @Test(arguments: ["scan corrections", "precorrection", "correctionals"])
    func leavesTheTextOutWhenItIsInsideAnotherWord(_ current: String) throws {
        #expect(
            try name(Self.payroll, current: current, siblings: Self.series) == "Payroll 2026.03")
    }

    @Test func comparesTheTextWithoutThePunctuationAtItsEnds() throws {
        #expect(try name("{text}[ - draft]", current: "scan draft") == "Letter - draft")
    }

    @Test func comparesSeveralWordsTogether() throws {
        #expect(try name("{text}[ second copy]", current: "copy second") == "Letter")
        #expect(try name("{text}[ second copy]", current: "a second copy") == "Letter second copy")
    }

    @Test func leavesOutAPartWithoutLettersOrDigits() throws {
        #expect(try name("{text}[ - ]", current: "a - b") == "Letter")
    }

    @Test func keepsAnOptionalPartWithAFieldTreewiseFills() throws {
        #expect(
            try NameTemplate.parse("{text}[ {folder}]", fields: Self.fields).get().names(
                from: ["text": .text("Letter"), "folder": .text("Tax")],
                context: .init(siblingNames: [], currentName: "scan", fileYear: nil)
            ).first?.name == "Letter Tax")
    }

    @Test func keepsTheTextAtTheEndOfAnOptionalPart() throws {
        let template = try NameTemplate.parse("{text}[ - {folder} final]", fields: Self.fields)
            .get()
        #expect(
            template.name(from: ["text": .text("Letter"), "folder": .text("Tax")])
                == "Letter - Tax final")
    }

    // MARK: Inside a choice of parts

    private static let tax = "Tax - <Sales {year}.Q{seq:4}|Payroll {year}.{seq:12}[ correction]>"

    @Test func makesAPartOfAChoiceWithAndWithoutTheText() throws {
        let siblings = ["Tax - Payroll 2026.01", "Tax - Payroll 2026.01 correction"]
        #expect(try name(Self.tax, current: "scan", siblings: siblings) == "Tax - Payroll 2026.02")
        #expect(
            try name(Self.tax, current: "payroll correction", siblings: siblings)
                == "Tax - Payroll 2026.02 correction")
    }

    @Test(arguments: ["Tax - Payroll 2026.01", "Tax - Payroll 2026.01 correction"])
    func recognizesAPartOfAChoiceWithAndWithoutTheText(_ name: String) throws {
        #expect(try NameTemplate.parse(Self.tax, fields: Self.fields).get().matches(name))
    }

    @Test(arguments: [
        "Tax <Sales[ {text}]|Payroll>", "Tax <Sales[ final|Payroll]>", "Tax <Sales[ final>]",
    ])
    func refusesOtherOptionalPartsInsideAChoice(_ text: String) {
        guard case .failure = NameTemplate.parse(text, fields: Self.fields) else {
            Issue.record("\(text) is accepted")
            return
        }
    }

    @Test func recognizesANameWithAndWithoutThePart() throws {
        let template = try NameTemplate.parse(Self.payroll, fields: Self.fields).get()
        #expect(template.matches("Payroll 2026.02"))
        #expect(template.matches("Payroll 2026.02 correction"))
    }
}
