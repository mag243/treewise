import Testing
import TreewiseCore

/// The check on a tree of folders before Treewise makes it: what an add-on returns or a file
/// holds is only names, relative to the folder it is made in (ADR 0091).
@Suite struct FolderTreeCheckTests {
    @Test func passesATreeOfOrdinaryNames() throws {
        let tree = FolderTree(
            name: "2027",
            folders: [FolderTree(name: "Tax"), FolderTree(name: "Summary {year}")])
        try tree.check()
    }

    @Test(arguments: ["", "  ", ".", "..", "a/b", "../Up", "a:b"])
    func refusesANameThatCannotBeMade(_ name: String) {
        let tree = FolderTree(name: "2027", folders: [FolderTree(name: name)])
        #expect(throws: FolderTree.Problem.invalidName(name)) { try tree.check() }
    }

    @Test func refusesAHiddenName() {
        let tree = FolderTree(name: ".secret")
        #expect(throws: FolderTree.Problem.hiddenName(".secret")) { try tree.check() }
    }

    @Test func refusesTwoFoldersOfTheSameName() {
        let tree = FolderTree(
            name: "2027", folders: [FolderTree(name: "Tax"), FolderTree(name: "tax")])
        let problem = #expect(throws: FolderTree.Problem.self) { try tree.check() }
        let named = ["Tax", "tax"].map { FolderTree.Problem.sameName($0) }
        #expect(problem.map(named.contains) == true, "either of the two")
    }

    @Test func findsTwinsOnlyOnceTheYearIsFilledIn() throws {
        let template = FolderTree(
            name: "Archive", folders: [FolderTree(name: "2027"), FolderTree(name: "{year}")])
        try template.check()
        #expect(throws: FolderTree.Problem.sameName("2027")) {
            try template.filling(year: 2027).check()
        }
    }

    @Test func refusesTooManyFolders() {
        let many = (0...FolderTree.mostFolders).map { FolderTree(name: "Folder \($0)") }
        #expect(throws: FolderTree.Problem.tooManyFolders) {
            try FolderTree(name: "Root", folders: many).check()
        }
    }

    @Test func refusesATreeTooDeep() {
        var tree = FolderTree(name: "Deepest")
        for level in 0..<FolderTree.mostLevels {
            tree = FolderTree(name: "Level \(level)", folders: [tree])
        }
        #expect(throws: FolderTree.Problem.tooDeep) { try tree.check() }
    }
}
