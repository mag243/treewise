import Foundation
import Testing
import TreewiseCore

/// Which state an item in a repository has, a folder's from its contents (ADR 0149).
@Suite struct GitItemStateTests {
    private func status(_ records: String...) -> GitRepositoryStatus {
        GitRepositoryStatus(porcelain: Data(records.map { $0 + "\0" }.joined().utf8))
    }

    private let hashes = "100644 100644 100644 a b"

    @Test func anUnchangedItemHasNoState() {
        let state = status("1 .M N... \(hashes) docs/a.txt")
        #expect(state.state(of: "docs/b.txt") == nil)
        #expect(state.state(of: "other") == nil)
    }

    @Test(arguments: [
        "1 .M N... 100644 100644 100644 a b src/app/main.swift",
        "? src/app/main.swift",
        "1 .D N... 100644 100644 100644 a b src/app/main.swift",
    ])
    func aFolderHoldingAChangeIsModifiedUpToTheTop(_ record: String) {
        let state = status(record)
        #expect(state.state(of: "src") == .modified)
        #expect(state.state(of: "src/app") == .modified)
    }

    @Test func aFolderHoldingAConflictIsInConflictUpToTheTop() {
        let state = status(
            "1 .M N... \(hashes) src/app/other.swift",
            "u UU N... 100644 100644 100644 100644 a b c src/app/main.swift")
        #expect(state.state(of: "src") == .conflict)
        #expect(state.state(of: "src/app") == .conflict)
        #expect(state.state(of: "docs") == nil)
    }

    @Test func aFolderHoldingOnlyIgnoredItemsHasNoState() {
        let state = status("! src/debug.log")
        #expect(state.state(of: "src") == nil)
    }

    @Test func aFolderGitReportsWhollyUntrackedIsNewAndSoIsWhatItHolds() {
        let state = status("? fresh/")
        #expect(state.state(of: "fresh") == .new)
        #expect(state.state(of: "fresh/deep/a.txt") == .new)
    }

    @Test func theFolderAboveAnUntrackedFolderIsModified() {
        #expect(status("? src/fresh/").state(of: "src") == .modified)
    }

    @Test func anIgnoredFolderAndWhatItHoldsAreIgnored() {
        let state = status("! build/")
        #expect(state.state(of: "build") == .ignored)
        #expect(state.state(of: "build/out/app.o") == .ignored)
        #expect(state.state(of: "builder") == nil, "a name that only starts the same")
    }

    @Test func theTopFolderHasChangesWhenAnythingChanged() {
        #expect(status("? a.txt").hasChanges)
        #expect(!status("! debug.log").hasChanges)
        #expect(!status("# branch.head main").hasChanges)
    }
}
