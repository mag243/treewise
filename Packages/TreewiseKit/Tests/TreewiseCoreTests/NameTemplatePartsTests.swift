import Foundation
import Testing
import TreewiseCore

/// A choice of parts, and `{year}` and `{seq}` that continue a series (ADR 0064).
@Suite struct NameTemplatePartsTests {
    private static let fields =
        [
            NameTemplate.Field(name: "date", kind: .date),
            NameTemplate.Field(name: "text", kind: .text),
            NameTemplate.Field(name: "number", kind: .number),
        ] + NameTemplate.Field.suppliedByTreewise
    private static let tax =
        "Tax - <Sales {year}.Q{seq:4}|Payroll {year}.{seq:12}|{text}>"

    private func template(_ text: String) throws -> NameTemplate {
        try NameTemplate.parse(text, fields: Self.fields).get()
    }

    private func problem(_ text: String) -> NameTemplate.Problem? {
        if case .failure(let problem) = NameTemplate.parse(text, fields: Self.fields) {
            return problem
        }
        return nil
    }

    private func names(
        _ text: String, values: [String: NameTemplate.Value] = ["text": .text("Letter")],
        siblings: [String] = [], current: String = "scan", year: Int? = 2026
    ) throws -> [String] {
        try template(text).names(
            from: values,
            context: .init(siblingNames: siblings, currentName: current, fileYear: year)
        ).map(\.name)
    }

    // MARK: A choice of parts

    @Test(arguments: ["Tax - Sales 2026.Q1", "Tax - Payroll 2026.01", "Tax - A letter"])
    func recognizesANameThatFitsAnyPart(_ name: String) throws {
        #expect(try template(Self.tax).matches(name))
    }

    @Test func recognizesNoNameThatFitsNoPart() throws {
        #expect(try !template("Tax - <Sales|Payroll>").matches("Tax - Rent"))
    }

    @Test func makesAnOptionForEachPart() throws {
        #expect(try names("Tax - <Sales|Payroll>") == ["Tax - Sales", "Tax - Payroll"])
    }

    @Test func putsThePartTheCurrentNameFitsFirst() throws {
        let made = try names("Tax - <Sales|Payroll>", current: "Tax - Payroll")
        #expect(made == ["Tax - Payroll", "Tax - Sales"])
    }

    @Test func putsThePartMostNamesInTheFolderFitNext() throws {
        let made = try names(
            "Tax - <Sales|Payroll>", siblings: ["Tax - Payroll", "Tax - Payroll", "Tax - Sales"])
        #expect(made == ["Tax - Payroll", "Tax - Sales"])
    }

    @Test func putsAPartWithoutFixedTextLast() throws {
        let made = try names("Tax - <{text}|Sales>", siblings: ["Tax - A", "Tax - B"])
        #expect(made == ["Tax - Sales", "Tax - Letter"])
    }

    @Test func aPartWithoutItsModulesValuesGivesNoOption() throws {
        #expect(try names("Tax - <Sales|{number}>") == ["Tax - Sales"])
    }

    // MARK: The next period

    @Test func continuesTheSeriesOfEachPart() throws {
        let made = try names(
            Self.tax,
            siblings: ["Tax - Sales 2025.Q2", "Tax - Sales 2025.Q3", "Tax - Payroll 2025.07"])
        #expect(made.prefix(2) == ["Tax - Sales 2025.Q4", "Tax - Payroll 2025.08"])
    }

    @Test func aCycleStartsAgainInTheNextYear() throws {
        let made = try names(Self.tax, siblings: ["Tax - Sales 2025.Q4"])
        #expect(made.first == "Tax - Sales 2026.Q1")
    }

    @Test func takesTheHighestPeriodNotTheLastName() throws {
        let made = try names(Self.tax, siblings: ["Tax - Sales 2026.Q1", "Tax - Sales 2025.Q4"])
        #expect(made.first == "Tax - Sales 2026.Q2")
    }

    @Test func aNewSeriesStartsAtOneInTheWidthOfItsCycle() throws {
        let made = try names(Self.tax, year: 2026)
        #expect(made.prefix(2) == ["Tax - Sales 2026.Q1", "Tax - Payroll 2026.01"])
    }

    @Test func aNewSeriesTakesTheYearOfTheFilesDate() throws {
        let made = try template(Self.tax).names(
            from: ["text": .text("Letter")],
            context: .init(siblingNames: [], currentName: "scan", fileYear: 2024))
        #expect(made.first?.name == "Tax - Sales 2024.Q1")
        #expect(made.first?.usesFileYear == true)
    }

    @Test func aContinuedSeriesDoesNotUseTheFilesDate() throws {
        let made = try template(Self.tax).names(
            from: ["text": .text("Letter")],
            context: .init(
                siblingNames: ["Tax - Sales 2025.Q3"], currentName: "scan", fileYear: 2024))
        #expect(made.first?.usesFileYear == false)
    }

    @Test func aSequenceWithoutACycleKeepsCountingInItsWidth() throws {
        let made = try names("Letter {seq}", siblings: ["Letter 008", "Letter 009"])
        #expect(made == ["Letter 010"])
    }

    @Test func aYearWithoutASequenceIsTheYearOfTheFilesDate() throws {
        #expect(try names("Report {year}", year: 2025) == ["Report 2025"])
    }

    @Test func aYearWithoutAFileDateIsAGap() throws {
        #expect(try names("Report {year}", year: nil) == ["Report \(NameTemplate.gap)"])
    }

    // MARK: Refusals

    @Test func refusesAnUnclosedChoice() {
        #expect(problem("Tax <Sales|Payroll") == .unbalancedAngleBrackets)
        #expect(problem("Tax Sales>") == .unbalancedAngleBrackets)
    }

    @Test func refusesAnEmptyPart() {
        #expect(problem("Tax <Sales|>") == .emptyAlternative)
    }

    @Test func refusesAChoiceAndAnOptionalPartInsideEachOther() {
        #expect(problem("Tax [<Sales|Payroll>]") == .nestedChoiceOfParts)
        #expect(problem("Tax <Sales[ {text}]|Payroll>") == .nestedChoiceOfParts)
        #expect(problem("Tax <Sales <A|B>|Payroll>") == .nestedChoiceOfParts)
    }

    @Test(arguments: ["{seq:1}", "{seq:x}", "{year:4}"])
    func refusesAWrongNumberAfterAColon(_ text: String) {
        #expect(problem("Letter \(text)") == .invalidFormat)
    }
}
