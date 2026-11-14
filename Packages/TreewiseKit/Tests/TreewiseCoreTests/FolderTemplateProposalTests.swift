import Testing

@testable import TreewiseCore

/// What the sheet proposes for a template's number and year (ADR 0095, ADR 0096).
@Suite struct FolderTemplateProposalTests {
    private static let none = FolderContents()
    private static let year = FolderTree(
        name: "{year}", folders: [FolderTree(name: "Receipts"), FolderTree(name: "Tax")])

    private static func values(year: Int?) -> FolderTemplateValues {
        FolderTemplateValues(year: year, text: nil, number: nil, date: nil, language: .english)
    }

    // MARK: The number

    @Test func proposesTheNumberAfterTheHighestBesideTheRoot() {
        let root = FolderTree(name: "P-{seq:0001-} {text}")
        let number = root.proposedNumber(
            beside: ["P-0141 Bakker", "P-0142 Smit", "Archive"], values: Self.values(year: nil))
        #expect(number == FolderTemplateValues.Number(value: 143, width: 4))
    }

    @Test func takesTheWidthOfTheNumbersThereWhenThePatternWritesNone() {
        let root = FolderTree(name: "P-{seq} {text}")
        let number = root.proposedNumber(beside: ["P-0142 Smit"], values: Self.values(year: nil))
        #expect(number == FolderTemplateValues.Number(value: 143, width: 4))
    }

    @Test func startsTheSeriesWhenNoFolderFits() {
        let root = FolderTree(name: "P-{seq:0001-} {text}")
        let number = root.proposedNumber(beside: ["Archive"], values: Self.values(year: nil))
        #expect(number == FolderTemplateValues.Number(value: 1, width: 4))
    }

    @Test func countsWithinTheYearChosen() {
        let root = FolderTree(name: "{year}-{seq:001-} {text}")
        let beside = ["2026-014 Bakker", "2027-002 Smit"]
        #expect(root.proposedNumber(beside: beside, values: Self.values(year: 2027))?.value == 3)
        #expect(root.proposedNumber(beside: beside, values: Self.values(year: 2028))?.value == 1)
    }

    @Test func proposesNoNumberWithoutASeq() {
        #expect(
            FolderTree(name: "{text}").proposedNumber(beside: [], values: Self.values(year: nil))
                == nil)
    }

    // MARK: The year

    @Test func proposesTheYearAfterTheHighestWhenThatOneIsComplete() {
        let contents = FolderContents(folders: [
            "2026": FolderContents(folders: ["Receipts": Self.none, "Tax": Self.none])
        ])
        #expect(Self.year.proposedYear(in: contents, currentYear: 2026) == 2027)
    }

    @Test func proposesTheHighestYearWhileItLacksFoldersOfTheTemplate() {
        let contents = FolderContents(folders: [
            "2026": FolderContents(folders: ["Receipts": Self.none, "Tax": Self.none]),
            "2027": FolderContents(folders: ["Tax": Self.none]),
        ])
        #expect(Self.year.proposedYear(in: contents, currentYear: 2026) == 2027)
    }

    @Test func proposesTheCurrentYearWithoutAYearsFolder() {
        let contents = FolderContents(folders: ["Archive": Self.none, "Tax 2020": Self.none])
        #expect(Self.year.proposedYear(in: contents, currentYear: 2026) == 2026)
    }

    @Test func proposesTheYearAfterTheHighestWhenOtherFieldsAreToBeFilled() {
        let root = FolderTree(name: "{year}", folders: [FolderTree(name: "Summary {text}")])
        let contents = FolderContents(folders: ["2027": FolderContents()])
        #expect(root.proposedYear(in: contents, currentYear: 2026) == 2028)
    }
}
