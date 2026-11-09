import Foundation
import Testing

@testable import TreewiseCore

/// What an archive should hold after a change, to check the new one by (ADR 0078).
@Suite struct ArchiveChangeTests {
    private func tree(_ names: [String]) -> ArchiveTree {
        ArchiveTree(
            entries: names.map {
                ArchiveEntry(storedName: $0, isFolder: $0.hasSuffix("/"), size: 1, modified: nil)
            })
    }

    @Test func listsWhatItHolds() {
        #expect(tree(["a.txt", "d/b.txt"]).paths == ["a.txt", "d", "d/b.txt"])
    }

    @Test func addingBringsItsFoldersToo() {
        let result = tree(["a.txt"]).paths(after: .add(["n/m/new.txt"]))
        #expect(result == ["a.txt", "n", "n/m", "n/m/new.txt"])
    }

    @Test func replacingChangesNothingInTheList() {
        #expect(tree(["a.txt"]).paths(after: .add(["a.txt"])) == ["a.txt"])
    }

    @Test func removingTakesWhatIsBelow() {
        let result = tree(["a.txt", "d/b.txt", "d/e/c.txt", "de.txt"]).paths(after: .remove(["d"]))
        #expect(result == ["a.txt", "de.txt"])
    }

    @Test func removingTheLastEntryKeepsItsFolder() {
        let result = tree(["d/", "d/b.txt"]).paths(after: .remove(["d/b.txt"]))
        #expect(result == ["d"])
    }

    @Test func removingTheLastEntryTakesAFolderOnlyItNamed() {
        #expect(tree(["d/b.txt"]).paths(after: .remove(["d/b.txt"])).isEmpty)
    }

    @Test func relocatingAFileRenamesIt() {
        let result = tree(["a.txt", "d/"]).paths(after: .relocate(from: "a.txt", to: "d/z.txt"))
        #expect(result == ["d", "d/z.txt"])
    }

    @Test func relocatingAFolderTakesWhatIsBelow() {
        let result = tree(["d/b.txt", "d/e/c.txt", "de.txt"])
            .paths(after: .relocate(from: "d", to: "x"))
        #expect(result == ["de.txt", "x", "x/b.txt", "x/e", "x/e/c.txt"])
    }

    @Test func aNewFolderIsAnAddition() {
        #expect(tree(["a.txt"]).paths(after: .add(["n"])) == ["a.txt", "n"])
    }

    @Test func namesCompareUnicodeNormalised() {
        let composed = "caf\u{E9}.txt"
        let decomposed = "cafe\u{301}.txt"
        #expect(tree([decomposed]).paths == tree([composed]).paths)
    }

    @Test func theCheckFindsAMissingEntry() {
        let new = tree(["a.txt"])
        #expect(!new.holdsExactly(["a.txt", "b.txt"]))
    }

    @Test func theCheckFindsAnEntryTooMany() {
        let new = tree(["a.txt", "b.txt"])
        #expect(!new.holdsExactly(["a.txt"]))
    }

    @Test func theCheckAcceptsTheExpected() {
        let old = tree(["a.txt"])
        let new = tree(["a.txt", "n/new.txt"])
        #expect(new.holdsExactly(old.paths(after: .add(["n/new.txt"]))))
    }
}
