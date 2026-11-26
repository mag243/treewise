import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Reading real repositories made in a `TempDirectory` with the user's git (ADR 0149).
@Suite(.enabled(if: GitTool.find() != nil, "needs git"))
struct GitStatusReaderTests {
    let directory: TempDirectory
    let reader = GitStatusReader()

    init() throws {
        directory = try TempDirectory()
    }

    /// The repository in `folder` of the temporary directory, made with one commit.
    private func makeRepository(_ folder: String = "repo") throws -> String {
        let path = try directory.makeFolder(folder).path
        try git(["init", "-q", "-b", "main"], in: path)
        try directory.makeFile("\(folder)/tracked.txt", contents: "one\n")
        try directory.makeFile("\(folder)/.gitignore", contents: "*.log\nbuild/\n")
        try commitAll("first", in: path)
        return path
    }

    private func commitAll(_ message: String, in path: String) throws {
        try git(["add", "-A"], in: path)
        try git(["commit", "-q", "-m", message], in: path)
    }

    private func status(of path: String) async throws -> (GitRepository, GitRepositoryStatus) {
        let repository = try #require(await reader.repository(holding: FileItem.ID(path)))
        return (repository, try await reader.status(of: repository))
    }

    @Test func findsTheTopFolderFromAFolderInsideInItsOwnTerms() async throws {
        let top = try makeRepository()
        let inner = try directory.makeFolder("repo/src/app").path
        let repository = try #require(await reader.repository(holding: FileItem.ID(inner)))
        #expect(repository.top == FileItem.ID(top))
        #expect(reader.relativePath(of: FileItem.ID(inner), in: repository) == "src/app")
        #expect(reader.relativePath(of: FileItem.ID(top), in: repository)?.isEmpty == true)
        #expect(reader.relativePath(of: FileItem.ID(directory.path), in: repository) == nil)
    }

    @Test func aFolderOutsideARepositoryHasNone() async throws {
        let plain = try directory.makeFolder("plain").path
        #expect(await reader.repository(holding: FileItem.ID(plain)) == nil)
    }

    @Test func theGitDataIsNoWorkingCopy() async throws {
        let top = try makeRepository()
        #expect(await reader.repository(holding: FileItem.ID(top + "/.git")) == nil)
    }

    @Test func marksTheTopFolderWithoutRunningGit() throws {
        let top = try makeRepository()
        #expect(reader.isRepositoryTop(FileItem.ID(top)))
        #expect(!reader.isRepositoryTop(FileItem.ID(directory.path)))
    }

    @Test func readsNewModifiedAndIgnoredItems() async throws {
        let top = try makeRepository()
        try directory.makeFile("repo/tracked.txt", contents: "two\n")
        try directory.makeFile("repo/notes.txt")
        try directory.makeFile("repo/debug.log")
        try directory.makeFolder("repo/build")
        try directory.makeFile("repo/build/out.o")
        let (_, state) = try await status(of: top)
        #expect(state.head == .branch("main"))
        #expect(state.state(of: "tracked.txt") == .modified)
        #expect(state.state(of: "notes.txt") == .new)
        #expect(state.state(of: "debug.log") == .ignored)
        #expect(state.state(of: "build/out.o") == .ignored)
    }

    @Test func readsNamesWithSpacesNewlinesAndAccentsAsTheDiskHasThem() async throws {
        let top = try makeRepository()
        try directory.makeFile("repo/with space.txt")
        try directory.makeFile("repo/line\nbreak.txt")
        let decomposed = try directory.makeFile("repo/cafe\u{301}.txt")
        let (repository, state) = try await status(of: top)
        #expect(state.state(of: "with space.txt") == .new)
        #expect(state.state(of: "line\nbreak.txt") == .new)
        let path = try #require(
            reader.relativePath(of: FileItem.ID(decomposed.path), in: repository))
        #expect(state.state(of: path) == .new)
    }

    @Test func readsAConflict() async throws {
        let top = try makeRepository()
        try git(["switch", "-q", "-c", "other"], in: top)
        try directory.makeFile("repo/tracked.txt", contents: "other\n")
        try commitAll("other", in: top)
        try git(["switch", "-q", "main"], in: top)
        try directory.makeFile("repo/tracked.txt", contents: "main\n")
        try commitAll("main", in: top)
        _ = try? git(["merge", "-q", "other"], in: top)
        let (_, state) = try await status(of: top)
        #expect(state.state(of: "tracked.txt") == .conflict)
    }

    @Test func readsADetachedHead() async throws {
        let top = try makeRepository()
        try git(["switch", "-q", "--detach"], in: top)
        let (_, state) = try await status(of: top)
        guard case .detached(let hash) = state.head else {
            Issue.record("not detached: \(String(describing: state.head))")
            return
        }
        #expect(hash.count == 7)
    }

    @Test func readsHowFarAheadAndBehindTheUpstreamIs() async throws {
        let origin = try makeRepository("origin")
        let clone = directory.url("clone").path
        try git(["clone", "-q", origin, clone], in: directory.path)
        try directory.makeFile("origin/theirs.txt")
        try commitAll("theirs", in: origin)
        try directory.makeFile("clone/mine.txt")
        try commitAll("mine", in: clone)
        try git(["fetch", "-q"], in: clone)
        let (_, state) = try await status(of: clone)
        #expect(state.upstream == .following(ahead: 1, behind: 1))
    }

    @Test func readsAnUpstreamThatWasDeleted() async throws {
        let origin = try makeRepository("origin")
        try git(["branch", "feature"], in: origin)
        let clone = directory.url("clone").path
        try git(["clone", "-q", origin, clone], in: directory.path)
        try git(["switch", "-q", "feature"], in: clone)
        try git(["branch", "-q", "-D", "feature"], in: origin)
        try git(["fetch", "-q", "--prune"], in: clone)
        let (_, state) = try await status(of: clone)
        #expect(state.upstream == .gone)
    }

    @Test func withoutGitNothingIsRead() async throws {
        let top = try makeRepository()
        let none = GitStatusReader(tool: nil)
        #expect(!none.hasGit)
        #expect(await none.repository(holding: FileItem.ID(top)) == nil)
    }

    @Test func findsNoGitWhereThereIsNone() {
        #expect(GitTool.find(developerDirectory: { nil }, candidates: ["/nonexistent/git"]) == nil)
        #expect(
            GitTool.find(developerDirectory: { nil }, candidates: ["/nonexistent/git", "/bin/ls"])
                == GitTool(executable: "/bin/ls"))
    }

    @Test func neverRunsTheGitThatAsksToInstallTheCommandLineTools() {
        #expect(!GitTool.homebrewCandidates.contains("/usr/bin/git"))
        #expect(GitTool.find(developerDirectory: { nil }) != GitTool(executable: "/usr/bin/git"))
    }

    @Test func hearsAFileChangingInPlaceInAFolderInside() async throws {
        let top = try makeRepository()
        try directory.makeFolder("repo/src")
        try directory.makeFile("repo/src/main.swift")
        try commitAll("src", in: top)
        let repository = try #require(await reader.repository(holding: FileItem.ID(top)))
        let heard = try await Heard.listening(to: reader.changes(of: repository))
        defer { heard.stop() }

        let handle = try FileHandle(forWritingTo: directory.url("repo/src/main.swift"))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("changed\n".utf8))
        try handle.close()

        #expect(await heard.hears { $0.contains("src/main.swift") })
    }

    @Test func hearsACommitAsAChangeInTheGitData() async throws {
        let top = try makeRepository()
        try directory.makeFile("repo/tracked.txt", contents: "two\n")
        let repository = try #require(await reader.repository(holding: FileItem.ID(top)))
        let heard = try await Heard.listening(to: reader.changes(of: repository))
        defer { heard.stop() }

        try commitAll("changed", in: top)

        #expect(await heard.hears { $0.contains("") })
    }

    @Test func readingTheStateWakesNoWatching() async throws {
        let top = try makeRepository()
        try directory.makeFile("repo/tracked.txt", contents: "two\n")
        let repository = try #require(await reader.repository(holding: FileItem.ID(top)))
        let heard = try await Heard.listening(to: reader.changes(of: repository))
        defer { heard.stop() }

        _ = try await reader.status(of: repository)

        #expect(!(await heard.hears { _ in true }), "git status wrote what it reads")
    }
}

/// The batches of a repository's changes, heard from after the stream had time to start,
/// so a change made before it is not among them.
private final class Heard: Sendable {
    /// How long a change may take to arrive: FSEvents gathers events for 0.3 seconds.
    private static let deadline = Duration.seconds(2)
    /// How long the stream gets to start, and earlier changes to arrive, before listening.
    private static let start = Duration.milliseconds(800)
    private static let poll = Duration.milliseconds(50)

    private let batches = Mutex<[[String]]>([])
    private let listening = Mutex<Task<Void, Never>?>(nil)

    static func listening(to events: AsyncStream<[String]>) async throws -> Heard {
        let heard = Heard()
        let task = Task {
            for await batch in events { heard.batches.withLock { $0.append(batch) } }
        }
        heard.listening.withLock { $0 = task }
        try await Task.sleep(for: start)
        heard.batches.withLock { $0 = [] }
        return heard
    }

    /// Whether a batch `matches` arrives before the deadline.
    func hears(_ matches: @escaping ([String]) -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let end = clock.now + Self.deadline
        while clock.now < end {
            if batches.withLock({ $0.contains(where: matches) }) { return true }
            try? await Task.sleep(for: Self.poll)
        }
        return batches.withLock { $0.contains(where: matches) }
    }

    func stop() {
        listening.withLock { $0?.cancel() }
    }
}

/// Runs git for a test, apart from the user's own settings, with a name to commit under.
@discardableResult
private func git(_ arguments: [String], in folder: String) throws -> String {
    let tool = try #require(GitTool.find())
    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool.executable)
    process.arguments =
        ["-C", folder, "-c", "user.name=Test", "-c", "user.email=test@example.com"] + arguments
    process.environment = [
        "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "LC_ALL": "C",
    ]
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(bytes: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw GitTestFailure(arguments: arguments, output: text)
    }
    return text
}

private struct GitTestFailure: Error, CustomStringConvertible {
    let arguments: [String]
    let output: String
    var description: String { "git \(arguments.joined(separator: " ")): \(output)" }
}
