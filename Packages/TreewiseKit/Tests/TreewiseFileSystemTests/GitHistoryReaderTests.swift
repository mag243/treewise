import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Reading an item's history from real repositories made in a `TempDirectory` with the
/// user's git (ADR 0153).
@Suite(.enabled(if: GitTool.find() != nil, "needs git"))
struct GitHistoryReaderTests {
    /// The commits of the long history `fast-import` makes, more than git writes at once.
    private static let longHistory = 400

    let directory: TempDirectory
    let reader = GitHistoryReader()

    init() throws {
        directory = try TempDirectory()
    }

    /// A repository in `repo` with Notes.md committed as "Add notes".
    private func makeRepository() async throws -> GitRepository {
        let path = try directory.makeFolder("repo").path
        try git(["init", "-q", "-b", "main"], in: path)
        try directory.makeFile("repo/Notes.md", contents: "one\ntwo\n")
        try commitAll("Add notes", in: path)
        return try #require(await GitStatusReader().repository(holding: FileItem.ID(path)))
    }

    private func commitAll(_ message: String, in path: String) throws {
        try git(["add", "-A"], in: path)
        try git(["commit", "-q", "-m", message], in: path)
    }

    private func history(_ path: String, isFolder: Bool = false, in repository: GitRepository)
        async throws -> [GitCommit]
    {
        var commits: [GitCommit] = []
        for try await part in reader.history(of: path, isFolder: isFolder, in: repository) {
            commits += part
        }
        return commits
    }

    @Test func readsAFilesCommitsNewestFirst() async throws {
        let repository = try await makeRepository()
        let top = repository.top.rawValue
        try directory.makeFile("repo/Notes.md", contents: "one\nthree\n")
        try git(["commit", "-q", "-am", "Change notes\n\nWith a body."], in: top)
        try directory.makeFile("repo/Other.md")
        try commitAll("Add other", in: top)
        let commits = try await history("Notes.md", in: repository)
        #expect(commits.map(\.subject) == ["Change notes", "Add notes"])
        #expect(commits[0].message == "Change notes\n\nWith a body.")
        #expect(commits[0].author == "Test")
        #expect(commits[0].path == "Notes.md")
    }

    @Test func followsARename() async throws {
        let repository = try await makeRepository()
        let top = repository.top.rawValue
        try git(["mv", "Notes.md", "Read me.md"], in: top)
        try commitAll("Rename", in: top)
        let commits = try await history("Read me.md", in: repository)
        #expect(commits.map(\.subject) == ["Rename", "Add notes"])
        #expect(commits[0].renamedFrom == "Notes.md")
        #expect(commits[1].path == "Notes.md")
    }

    @Test func aFoldersHistoryIsThatOfWhatItHolds() async throws {
        let repository = try await makeRepository()
        let top = repository.top.rawValue
        try directory.makeFolder("repo/src")
        try directory.makeFile("repo/src/a.swift")
        try commitAll("Add a", in: top)
        try directory.makeFile("repo/src/b.swift")
        try commitAll("Add b", in: top)
        #expect(
            try await history("src", isFolder: true, in: repository).map(\.subject) == [
                "Add b", "Add a",
            ])
        #expect(
            try await history("", isFolder: true, in: repository).map(\.subject) == [
                "Add b", "Add a", "Add notes",
            ])
    }

    @Test func aNameGitWouldReadAsAPatternIsReadAsIs() async throws {
        let repository = try await makeRepository()
        let top = repository.top.rawValue
        try directory.makeFile("repo/*.md", contents: "star\n")
        try commitAll("Add star", in: top)
        #expect(try await history("*.md", in: repository).map(\.subject) == ["Add star"])
    }

    @Test func readsALongHistoryWhole() async throws {
        let repository = try await makeRepository()
        try git(["fast-import", "--quiet"], in: repository.top.rawValue, input: fastImport())
        let commits = try await history("Long.txt", in: repository)
        #expect(commits.count == Self.longHistory)
        #expect(commits.first?.subject == "Change \(Self.longHistory)")
    }

    @Test func endingTheReadingEarlyStopsGit() async throws {
        let repository = try await makeRepository()
        try git(["fast-import", "--quiet"], in: repository.top.rawValue, input: fastImport())
        var first: [GitCommit] = []
        for try await part in reader.history(of: "Long.txt", isFolder: false, in: repository) {
            first = part
            break
        }
        #expect(!first.isEmpty)
        #expect(first.count < Self.longHistory, "the first part comes before git is done")
    }

    @Test func aCommitsChangesToAFile() async throws {
        let repository = try await makeRepository()
        try directory.makeFile("repo/Notes.md", contents: "one\nthree\n")
        try git(["commit", "-q", "-am", "Change"], in: repository.top.rawValue)
        let commit = try #require(try await history("Notes.md", in: repository).first)
        let diff = try await reader.changes(
            of: "Notes.md", in: commit, repository: repository, limit: nil)
        let file = try #require(diff.files.first)
        #expect(diff.files.count == 1)
        #expect(file.change == .modified)
        #expect(file.hunks.first?.lines.map(\.text) == ["one", "two", "three"])
        #expect(diff.isComplete)
    }

    @Test func theFirstCommitAddsTheFile() async throws {
        let repository = try await makeRepository()
        let commit = try #require(try await history("Notes.md", in: repository).first)
        let diff = try await reader.changes(
            of: "Notes.md", in: commit, repository: repository, limit: nil)
        #expect(diff.files.map(\.change) == [.added])
    }

    @Test func aRenamesChangesSayWhereTheFileCameFrom() async throws {
        let repository = try await makeRepository()
        let top = repository.top.rawValue
        try git(["mv", "Notes.md", "Read me.md"], in: top)
        try commitAll("Rename", in: top)
        let commit = try #require(try await history("Read me.md", in: repository).first)
        let diff = try await reader.changes(
            of: "Read me.md", in: commit, repository: repository, limit: nil)
        #expect(diff.files.map(\.change) == [.renamed(from: "Notes.md")])
        #expect(diff.files.first?.path == "Read me.md")
    }

    @Test func readsTheChangesNotCommittedYetStagedOrNot() async throws {
        let repository = try await makeRepository()
        try directory.makeFile("repo/Notes.md", contents: "one\ntwo\nthree\n")
        try git(["add", "Notes.md"], in: repository.top.rawValue)
        try directory.makeFile("repo/Notes.md", contents: "one\ntwo\nthree\nfour\n")
        let diff = try await reader.uncommittedChanges(
            of: "Notes.md", in: repository, limit: nil)
        let added = diff.files.first?.hunks.flatMap(\.lines).filter { $0.kind == .added }
        #expect(added?.map(\.text) == ["three", "four"])
    }

    @Test func anUnchangedFileHasNoUncommittedChanges() async throws {
        let repository = try await makeRepository()
        let diff = try await reader.uncommittedChanges(
            of: "Notes.md", in: repository, limit: nil)
        #expect(diff.files.isEmpty)
    }

    @Test func aLargeDiffIsReadInPartWithinItsLimit() async throws {
        let repository = try await makeRepository()
        let lines = (1...5_000).map { "line \($0)" }.joined(separator: "\n")
        try directory.makeFile("repo/Notes.md", contents: lines)
        let diff = try await reader.uncommittedChanges(
            of: "Notes.md", in: repository, limit: 4_096)
        #expect(!diff.isComplete)
        let count = diff.files.first?.hunks.first?.lines.count ?? 0
        #expect(count > 0 && count < 5_000)
    }

    @Test func withoutGitTheHistoryCannotBeRead() async throws {
        let repository = try await makeRepository()
        let none = GitHistoryReader(tool: nil)
        await #expect(throws: FileSystemError.self) {
            for try await _ in none.history(of: "Notes.md", isFolder: false, in: repository) {}
        }
    }

    /// A `fast-import` stream that commits Long.txt `longHistory` times on main, after the
    /// repository's own commit.
    private func fastImport() -> Data {
        var stream = ""
        for index in 1...Self.longHistory {
            let content = "version \(index)\n"
            let message = "Change \(index)\n"
            stream += "commit refs/heads/main\n"
            stream += "committer Test <test@example.com> \(1_700_000_000 + index) +0000\n"
            stream += "data \(message.utf8.count)\n\(message)"
            if index == 1 { stream += "from refs/heads/main^0\n" }
            stream += "M 100644 inline Long.txt\ndata \(content.utf8.count)\n\(content)\n"
        }
        return Data(stream.utf8)
    }
}
