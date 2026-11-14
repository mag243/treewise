import Testing
import TreewiseCore

/// The folders a template makes in a folder, beside what is there (ADR 0091).
@Suite struct FolderTemplatePlanTests {
    private static let year2027 = FolderTree(
        name: "2027",
        folders: [
            FolderTree(name: "Receipts", folders: [FolderTree(name: "Receipts Kept")]),
            FolderTree(name: "Tax"),
        ])

    private func states(_ plan: FolderTemplatePlan) -> [String] {
        plan.entries.map { "\($0.path.joined(separator: "/")) \($0.state)" }
    }

    @Test func makesEveryFolderInAnEmptyFolder() {
        let plan = FolderTemplatePlan(making: Self.year2027, in: FolderContents())
        #expect(
            states(plan) == [
                "2027 new", "2027/Receipts new", "2027/Receipts/Receipts Kept new", "2027/Tax new",
            ])
        #expect(plan.toMake.first == ["2027"], "a folder before the folders in it")
        #expect(plan.leftOut.isEmpty)
    }

    @Test func keepsTheFoldersThereAndFillsThem() {
        let there = FolderContents(folders: [
            "2027": FolderContents(folders: ["Tax": FolderContents(files: ["Return.pdf"])])
        ])
        let plan = FolderTemplatePlan(making: Self.year2027, in: there)
        #expect(
            states(plan) == [
                "2027 existing", "2027/Receipts new", "2027/Receipts/Receipts Kept new",
                "2027/Tax existing",
            ])
        #expect(plan.toMake == [["2027", "Receipts"], ["2027", "Receipts", "Receipts Kept"]])
    }

    @Test func fillsAFolderUnderTheNameItHas() {
        let there = FolderContents(folders: ["2027": FolderContents(folders: ["receipts": .init()])]
        )
        let plan = FolderTemplatePlan(making: Self.year2027, in: there)
        #expect(
            plan.toMake.contains(["2027", "receipts", "Receipts Kept"]), "as the disk names it")
        #expect(states(plan).contains("2027/receipts existing"))
    }

    @Test func comparesNamesAsTheFileSystemDoes() {
        let decomposed = "Cafe\u{301}"
        let tree = FolderTree(name: "Café")
        let plan = FolderTemplatePlan(
            making: tree, in: FolderContents(folders: [decomposed: .init()]))
        #expect(plan.toMake.isEmpty)
    }

    @Test func leavesOutAFolderWhereAFileHasItsName() {
        let there = FolderContents(folders: ["2027": FolderContents(files: ["Receipts"])])
        let plan = FolderTemplatePlan(making: Self.year2027, in: there)
        #expect(plan.leftOut == [["2027", "Receipts"]], "the folder and those below it")
        #expect(plan.toMake == [["2027", "Tax"]])
        #expect(states(plan) == ["2027 existing", "2027/Receipts leftOut", "2027/Tax new"])
    }

    @Test func leavesOutTheWholeTemplateWhenAFileHasItsRootName() {
        let plan = FolderTemplatePlan(making: Self.year2027, in: FolderContents(files: ["2027"]))
        #expect(plan.leftOut == [["2027"]])
        #expect(plan.toMake.isEmpty)
    }
}
