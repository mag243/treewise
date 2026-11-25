import Foundation
import Testing
import TreewiseCore

/// Reading `git status --porcelain=v2 --branch -z --ignored` into a repository's state
/// (ADR 0149). The records are copied from the output of git 2.56 on scratch repositories.
@Suite struct GitStatusParsingTests {
    /// The records as git writes them: each one ends in a 0 byte.
    private func status(_ records: String...) -> GitRepositoryStatus {
        GitRepositoryStatus(porcelain: Data(records.map { $0 + "\0" }.joined().utf8))
    }

    private let oid = "5009dc9bfa7e212d688d29909fa32e16d9d6741a"
    private let hashes =
        "100644 100644 100644 587be6b4c3f93f93c489c0111bba5596147a26cb "
        + "587be6b4c3f93f93c489c0111bba5596147a26cb"

    @Test func readsTheBranch() {
        let state = status("# branch.oid \(oid)", "# branch.head main")
        #expect(state.head == .branch("main"))
        #expect(state.upstream == nil)
    }

    @Test func aDetachedHeadShowsItsShortHash() {
        let state = status("# branch.oid \(oid)", "# branch.head (detached)")
        #expect(state.head == .detached("5009dc9"))
    }

    @Test func aRepositoryWithoutCommitsIsOnItsBranch() {
        let state = status("# branch.oid (initial)", "# branch.head main")
        #expect(state.head == .branch("main"))
    }

    @Test func readsHowFarTheBranchIsAheadAndBehind() {
        let state = status(
            "# branch.oid \(oid)", "# branch.head main", "# branch.upstream origin/main",
            "# branch.ab +2 -1")
        #expect(state.upstream == GitRepositoryStatus.Upstream(ahead: 2, behind: 1))
    }

    @Test func anUpstreamThatIsGoneHasNoCounts() {
        let state = status(
            "# branch.oid \(oid)", "# branch.head main", "# branch.upstream origin/gone")
        #expect(state.upstream == nil)
    }

    @Test func aChangedFileIsModified() {
        #expect(status("1 .M N... \(hashes) tracked.txt").state(of: "tracked.txt") == .modified)
        #expect(status("1 M. N... \(hashes) staged.txt").state(of: "staged.txt") == .modified)
    }

    @Test func anAddedFileIsNew() {
        #expect(status("1 A. N... \(hashes) added.txt").state(of: "added.txt") == .new)
    }

    @Test func anUntrackedFileIsNew() {
        #expect(status("? notes.txt").state(of: "notes.txt") == .new)
    }

    @Test func aFileInConflictIsInConflict() {
        let record = "u UU N... 100644 100644 100644 100644 a b c tracked.txt"
        #expect(status(record).state(of: "tracked.txt") == .conflict)
    }

    @Test func anIgnoredFileIsIgnored() {
        #expect(status("! debug.log").state(of: "debug.log") == .ignored)
    }

    @Test func aRenamedFileIsNewWhereItWentAndItsOldNameIsNoEntry() {
        let state = status("2 R. N... \(hashes) R100 new.txt", "old.txt", "? after.txt")
        #expect(state.state(of: "new.txt") == .new)
        #expect(state.state(of: "old.txt") == nil)
        #expect(state.state(of: "after.txt") == .new, "the old name is not read as a record")
    }

    @Test func aDeletedFileHasNoStateButItsFolderIsModified() {
        let state = status("1 .D N... \(hashes) docs/gone.txt")
        #expect(state.state(of: "docs/gone.txt") == nil)
        #expect(state.state(of: "docs") == .modified)
    }

    @Test func namesWithSpacesAndNewlinesAreReadWhole() {
        let state = status("? with space.txt", "? line\nbreak.txt", "1 .M N... \(hashes) a b.txt")
        #expect(state.state(of: "with space.txt") == .new)
        #expect(state.state(of: "line\nbreak.txt") == .new)
        #expect(state.state(of: "a b.txt") == .modified)
    }

    @Test func aNameIsFoundAsTheDiskWritesItDecomposed() {
        let state = status("? caf\u{E9}.txt")
        #expect(state.state(of: "cafe\u{301}.txt") == .new)
    }

    @Test func aNameThatIsNoUTF8LeavesTheOtherRecords() {
        var data = Data("? bad".utf8)
        data.append(contentsOf: [0xFF, 0xFE, 0])
        data.append(Data("? good.txt\0".utf8))
        #expect(GitRepositoryStatus(porcelain: data).state(of: "good.txt") == .new)
    }

    @Test func aRecordGitAddsLaterIsLeftAlone() {
        let state = status("# branch.oid \(oid)", "# stash 3", "x future record", "? a.txt")
        #expect(state.state(of: "a.txt") == .new)
    }
}
