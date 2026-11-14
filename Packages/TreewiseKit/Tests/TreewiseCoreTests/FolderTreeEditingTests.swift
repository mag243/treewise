import Testing

@testable import TreewiseCore

/// Editing a template's tree in Settings (ADR 0095): each change checked as a template is,
/// and folders kept in order by name. A folder is found by the names below the root.
@Suite struct FolderTreeEditingTests {
    private static let untitled = "untitled folder"
    private static let tree = FolderTree(
        name: "{year}",
        folders: [
            FolderTree(name: "Bank", folders: [FolderTree(name: "Savings")]),
            FolderTree(name: "Tax", folders: [FolderTree(name: "Returns")]),
        ])

    private func names(_ tree: FolderTree) -> [String] { tree.folders.map(\.name) }

    @Test func addsAnUntitledFolderInTheOneChosen() throws {
        let (edited, path) = try Self.tree.adding(in: ["Tax"], named: Self.untitled)
        #expect(path == ["Tax", Self.untitled])
        #expect(try names(#require(edited.folder(at: ["Tax"]))) == ["Returns", Self.untitled])
    }

    @Test func numbersAnUntitledFolderWhenTheNameIsTaken() throws {
        let (once, _) = try Self.tree.adding(in: [], named: Self.untitled)
        let (twice, path) = try once.adding(in: [], named: Self.untitled)
        #expect(path == ["untitled folder 2"])
        #expect(names(twice) == ["Bank", "Tax", Self.untitled, "untitled folder 2"])
    }

    @Test func renamesAFolderAndKeepsTheOrderByName() throws {
        let (edited, path) = try Self.tree.renaming(["Tax"], to: "Accounts")
        #expect(path == ["Accounts"])
        #expect(names(edited) == ["Accounts", "Bank"])
        #expect(try names(#require(edited.folder(at: ["Accounts"]))) == ["Returns"])
    }

    @Test func renamesTheRoot() throws {
        let (edited, path) = try Self.tree.renaming([], to: "P-{seq:001-} {text}")
        #expect(path.isEmpty)
        #expect(edited.name == "P-{seq:001-} {text}")
    }

    @Test func refusesANameThatIsAlreadyInTheSameFolder() {
        #expect(throws: FolderTree.Problem.sameName("bank")) {
            try Self.tree.renaming(["Tax"], to: "bank")
        }
    }

    @Test(arguments: [
        ("a/b", FolderTree.Problem.invalidName("a/b")),
        (".git", .hiddenName(".git")),
        ("{seq} Intake", .numberBelowTop("{seq} Intake")),
        ("{date:qq}", .invalidFormat("{date:qq}")),
    ])
    func refusesANameATemplateCannotHold(name: String, problem: FolderTree.Problem) {
        #expect(throws: problem) { try Self.tree.renaming(["Tax"], to: name) }
    }

    @Test func removesAFolderWithEverythingBelowIt() {
        let edited = Self.tree.removing(["Bank"])
        #expect(names(edited) == ["Tax"])
        #expect(edited.folder(at: ["Bank", "Savings"]) == nil)
    }

    @Test func movesAFolderIntoAnother() throws {
        let (edited, path) = try Self.tree.moving(["Bank", "Savings"], into: ["Tax"])
        #expect(path == ["Tax", "Savings"])
        #expect(try names(#require(edited.folder(at: ["Bank"]))).isEmpty)
        #expect(try names(#require(edited.folder(at: ["Tax"]))) == ["Returns", "Savings"])
    }

    @Test func refusesToMoveAFolderIntoItselfOrOneBelowIt() {
        #expect(throws: FolderTree.Problem.intoItself) {
            try Self.tree.moving(["Bank"], into: ["Bank"])
        }
        #expect(throws: FolderTree.Problem.intoItself) {
            try Self.tree.moving(["Bank"], into: ["Bank", "Savings"])
        }
    }

    @Test func refusesToMoveAFolderWhereItsNameIsTaken() throws {
        let (withReturns, _) = try Self.tree.adding(in: ["Bank"], named: "Returns")
        #expect(throws: FolderTree.Problem.sameName("Returns")) {
            try withReturns.moving(["Bank", "Returns"], into: ["Tax"])
        }
    }

    @Test func refusesAFolderBeyondTheMostFolders() throws {
        let full = FolderTree(
            name: "Full",
            folders: (1..<FolderTree.mostFolders).map { FolderTree(name: "Folder \($0)") })
        #expect(throws: FolderTree.Problem.tooManyFolders) {
            try full.adding(in: [], named: Self.untitled)
        }
    }
}
