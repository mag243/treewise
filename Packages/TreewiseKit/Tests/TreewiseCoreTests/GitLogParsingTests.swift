import Foundation
import Testing
import TreewiseCore

/// Reading `git log --follow -z --name-status` in `GitLogParser.format` into an item's
/// commits (ADR 0153). The records are laid out as git 2.56 writes them on scratch
/// repositories: the format's fields, a 0 byte, a newline, then the item's change.
@Suite struct GitLogParsingTests {
    private let first = "f4a1074a52ca329feb5b25e9b5e5abfc189ce183"
    private let second = "1064be9e158c314a41e08e6331ac9a8d2a404668"
    private let third = "26317230f1377b6fdb06556682" + "9de939e4414b5"

    /// One commit's record: the format's fields, then its change's fields, each ending in
    /// a 0 byte.
    private func record(
        _ hash: String, parents: [String] = [], author: String = "Ada Lovelace",
        email: String = "ada@example.com", time: Int = 1_795_864_787, message: String,
        change: [String] = []
    ) -> String {
        let fields = [hash, parents.joined(separator: " "), author, email, String(time), message]
        let status = change.isEmpty ? "" : "\n" + change.map { $0 + "\0" }.joined()
        return "\u{1E}" + fields.joined(separator: "\u{1F}") + "\u{1F}\0" + status
    }

    private func commits(_ records: String...) -> [GitCommit] {
        var parser = GitLogParser()
        return parser.append(Data(records.joined().utf8)) + parser.finish()
    }

    @Test func readsACommit() throws {
        let commit = try #require(
            commits(record(first, message: "Add the parser\n", change: ["A", "Parser.swift"]))
                .first)
        #expect(commit.id == first)
        #expect(commit.shortHash == "f4a1074")
        #expect(commit.author == "Ada Lovelace")
        #expect(commit.email == "ada@example.com")
        #expect(commit.date == Date(timeIntervalSince1970: 1_795_864_787))
        #expect(commit.parents.isEmpty)
        #expect(commit.path == "Parser.swift")
        #expect(commit.renamedFrom == nil)
    }

    @Test func readsTheCommitsNewestFirst() {
        let read = commits(
            record(third, parents: [second], message: "Change\n", change: ["M", "b.txt"]),
            record(second, parents: [first], message: "Rename\n", change: ["M", "b.txt"]),
            record(first, message: "First\n", change: ["A", "b.txt"]))
        #expect(read.map(\.id) == [third, second, first])
        #expect(read[0].parents == [second])
    }

    @Test func aMessageOfSeveralLinesKeepsItsBodyAndHasItsFirstLineAsSubject() throws {
        let commit = try #require(
            commits(
                record(
                    first, message: "Read the log\n\nIn parts, so the first\ncommits show.\n",
                    change: ["M", "a.txt"])
            ).first)
        #expect(commit.subject == "Read the log")
        #expect(commit.message == "Read the log\n\nIn parts, so the first\ncommits show.")
    }

    @Test func aRenameGivesTheNameTheItemHadBefore() throws {
        let commit = try #require(
            commits(record(second, message: "Rename\n", change: ["R100", "a.txt", "b.txt"]))
                .first)
        #expect(commit.path == "b.txt")
        #expect(commit.renamedFrom == "a.txt")
    }

    @Test func aCopyIsNoRename() throws {
        let commit = try #require(
            commits(record(second, message: "Copy\n", change: ["C75", "a.txt", "b.txt"])).first)
        #expect(commit.path == "b.txt")
        #expect(commit.renamedFrom == nil)
    }

    @Test func aCommitWithoutAChangeOfItsOwnHasNoPath() throws {
        // A merge, or a folder's history read without `--name-status`.
        let commit = try #require(
            commits(record(third, parents: [first, second], message: "Merge\n")).first)
        #expect(commit.parents == [first, second])
        #expect(commit.path == nil)
    }

    @Test func aNameWithSpacesAndANewlineIsReadWhole() throws {
        let commit = try #require(
            commits(record(first, message: "Add\n", change: ["A", "My notes\nold.md"])).first)
        #expect(commit.path == "My notes\nold.md")
    }

    @Test func aRecordSplitOverTwoPartsIsReadWhenItIsWhole() {
        let data = Data(
            (record(second, message: "Rename\n", change: ["R100", "a.txt", "b.txt"])
                + record(first, message: "First\n", change: ["A", "a.txt"])).utf8)
        let cut = data.count / 3
        var parser = GitLogParser()
        let early = parser.append(data.prefix(cut))
        let later = parser.append(data.dropFirst(cut))
        let last = parser.finish()
        #expect(early.isEmpty, "nothing is read before a record is whole")
        #expect(later.map(\.id) == [second])
        #expect(last.map(\.id) == [first], "the last record is whole when git ends")
    }

    @Test func aRecordThatIsNotACommitIsLeftOutWithoutLosingTheOthers() {
        let read = commits(
            "\u{1E}not a commit\u{1F}\0", record(first, message: "First\n", change: ["A", "a"]))
        #expect(read.map(\.id) == [first])
    }

    @Test func noOutputIsNoCommits() {
        #expect(commits().isEmpty)
    }
}
