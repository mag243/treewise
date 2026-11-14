import Testing

@testable import TreewiseCore

/// Repeating folders (ADR 0100): a folder whose name holds `{month}`, `{quarter}` or `{half}`
/// stands for one folder per month, quarter or half, each with the folders below it.
@Suite struct FolderRepeatTests {
    private static let english = FolderTemplateValues(year: 2026, language: .english)

    private static func year(_ month: String) -> FolderTree {
        FolderTree(
            name: "{year}",
            folders: [
                FolderTree(
                    name: month,
                    folders: [FolderTree(name: "Invoices"), FolderTree(name: "Receipts")]),
                FolderTree(name: "Tax"),
            ])
    }

    @Test func makesAFolderForEachMonthWithTheFoldersBelowIt() {
        let made = Self.year("{month:MM MMMM}").filling(Self.english)
        let months = made.folders.filter { $0.name != "Tax" }
        #expect(months.count == 12)
        #expect(months.first?.name == "01 January")
        #expect(months.last?.name == "12 December")
        #expect(months.allSatisfy { $0.folders.map(\.name) == ["Invoices", "Receipts"] })
        #expect(made.folders.contains { $0.name == "Tax" }, "a folder that does not repeat stays")
    }

    @Test(arguments: [
        ("{month}", ["01", "02", "03"]),
        ("{year}-{month:MM}", ["2026-01", "2026-02", "2026-03"]),
        ("{month:MMM}", ["Jan", "Feb", "Mar"]),
        ("{month:MMMM@nl}", ["januari", "februari", "maart"]),
    ])
    func writesAMonthInItsFormat(name: String, first: [String]) {
        let made = Self.year(name).filling(Self.english)
        let months = made.folders.map(\.name).filter { $0 != "Tax" }
        for name in first { #expect(months.contains(name)) }
        #expect(months.count == 12)
    }

    @Test func makesAFolderForEachQuarterAndEachHalf() {
        let quarters = Self.year("Q{quarter}").filling(Self.english)
        #expect(quarters.folders.map(\.name) == ["Q1", "Q2", "Q3", "Q4", "Tax"])
        let halves = Self.year("H{half}").filling(Self.english)
        #expect(halves.folders.map(\.name) == ["H1", "H2", "Tax"])
    }

    @Test func aRepeatIsNotAFieldTheSheetAsks() {
        #expect(Self.year("{month:MM}").fields == [.year])
        #expect(Self.year("Q{quarter}").fields == [.year])
    }

    @Test func aTemplateWithARepeatBelowTheRootIsOne() throws {
        try Self.year("{year}-{month:MM MMMM}").checkTemplate()
        try Self.year("H{half}").checkTemplate()
    }

    @Test func aRepeatCannotBeTheRoot() {
        let tree = FolderTree(name: "{month:MM}", folders: [FolderTree(name: "Invoices")])
        #expect(throws: FolderTree.Problem.repeatAtTop("{month:MM}")) {
            try tree.checkTemplate()
        }
    }

    @Test func aRepeatCannotBeInsideAnother() {
        let tree = FolderTree(
            name: "{year}",
            folders: [FolderTree(name: "Q{quarter}", folders: [FolderTree(name: "{month}")])])
        #expect(throws: FolderTree.Problem.repeatInRepeat("{month}")) {
            try tree.checkTemplate()
        }
    }

    @Test func aNameHoldsOneRepeatAtMost() {
        let tree = FolderTree(name: "{year}", folders: [FolderTree(name: "Q{quarter} {month}")])
        #expect(throws: FolderTree.Problem.repeatInRepeat("Q{quarter} {month}")) {
            try tree.checkTemplate()
        }
    }

    @Test(arguments: ["{month:yyyy}", "{month:dd}", "{month:MM yyyy}", "{quarter:q}", "{half:x}"])
    func aRepeatWithAFormatItDoesNotTakeIsInvalid(name: String) {
        let tree = FolderTree(name: "{year}", folders: [FolderTree(name: name)])
        #expect(throws: FolderTree.Problem.invalidFormat(name)) { try tree.checkTemplate() }
    }

    @Test func writesOneNameAsTheMonthQuarterOrHalfAsked() {
        #expect(
            FolderTree.name("{year}-{month:MM MMMM@nl}", repeatedAs: 3, values: Self.english)
                == "2026-03 maart")
        #expect(FolderTree.name("Q{quarter}", repeatedAs: 2, values: Self.english) == "Q2")
        #expect(FolderTree.name("Tax", repeatedAs: 1, values: Self.english) == nil)
    }

    @Test func theTreeMadeIsCheckedWithEveryRepeat() throws {
        try Self.year("{month:MM MMMM}").filling(Self.english).check()
    }
}
