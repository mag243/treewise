#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Reads an item's history on the local disk with the user's own git, never changing
    /// the repository (ADR 0153).
    ///
    /// The user's git settings may change what git writes; the options that would change
    /// what is read, such as `log.showSignature`, `diff.noprefix` or `color.ui`, are set
    /// back for each run, and a path is taken as it is, never as a pattern.
    public struct GitHistoryReader: GitHistoryReading {
        /// The git to run; `nil` when none is installed.
        public let tool: GitTool?

        /// Before the command: names as UTF-8, not octal, and paths never as patterns.
        private static let global = ["-c", "core.quotePath=false", "--literal-pathspecs"]
        /// What a diff is read with, whatever the user's settings.
        private static let diffOptions = [
            "--no-color", "--no-ext-diff", "--no-textconv", "--src-prefix=a/", "--dst-prefix=b/",
            "-M",
        ]

        /// Creates a reader that runs `tool`, by default the git `GitTool.find` finds.
        public init(tool: GitTool? = GitTool.find()) {
            self.tool = tool
        }

        public func history(of path: String, isFolder: Bool, in repository: GitRepository)
            -> AsyncThrowingStream<[GitCommit], any Error>
        {
            guard let tool else { return Self.failing() }
            // `--follow` takes one file; a folder's history needs none, as nothing renames it
            // as a whole. `--name-status` gives a file the path it had in each commit.
            let options =
                isFolder
                ? ["log", "-z", "--no-show-signature", "--no-color"]
                : [
                    "log", "--follow", "-M", "-z", "--name-status", "--no-show-signature",
                    "--no-color",
                ]
            let arguments =
                Self.global + options + [
                    "--format=" + GitLogParser.format, "--", Self.pathspec(path),
                ]
            let output = GitProcess.stream(tool, in: repository.top.rawValue, arguments)
            return AsyncThrowingStream { continuation in
                let reading = Task {
                    var parser = GitLogParser()
                    do {
                        for try await part in output {
                            let commits = parser.append(part)
                            if !commits.isEmpty { continuation.yield(commits) }
                        }
                        let last = parser.finish()
                        if !last.isEmpty { continuation.yield(last) }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in reading.cancel() }
            }
        }

        public func changes(
            of path: String, in commit: GitCommit, repository: GitRepository, limit: Int?
        ) async throws -> GitDiff {
            // A renamed file under both names, so git finds the rename.
            let paths = [commit.renamedFrom, commit.path ?? path].compactMap { $0 }
            let range =
                commit.parents.first.map { ["diff", $0, commit.id] }
                ?? ["show", "--format=", "--root", commit.id]
            return try await diff(range, paths: paths, in: repository, limit: limit)
        }

        public func uncommittedChanges(of path: String, in repository: GitRepository, limit: Int?)
            async throws -> GitDiff
        {
            try await diff(["diff", "HEAD"], paths: [path], in: repository, limit: limit)
        }

        /// Runs a diff command and reads its output, up to `limit` bytes; a part cut short
        /// ends at its last whole line.
        private func diff(
            _ command: [String], paths: [String], in repository: GitRepository, limit: Int?
        ) async throws -> GitDiff {
            guard let tool else { throw FileSystemError.unexpected("git is not installed") }
            let arguments =
                Self.global + command.prefix(1) + Self.diffOptions + command.dropFirst() + ["--"]
                + paths.map(Self.pathspec)
            var data = Data()
            var isComplete = true
            for try await part in GitProcess.stream(tool, in: repository.top.rawValue, arguments) {
                data.append(part)
                if let limit, data.count > limit {
                    isComplete = false
                    break
                }
            }
            if !isComplete, let limit {
                let cut = data.prefix(limit).lastIndex(of: UInt8(ascii: "\n")).map { $0 + 1 } ?? 0
                data = data.prefix(cut)
            }
            return GitDiff(files: GitDiff(unified: data).files, isComplete: isComplete)
        }

        /// The top folder's empty path as git takes it.
        private static func pathspec(_ path: String) -> String {
            path.isEmpty ? "." : path
        }

        private static func failing() -> AsyncThrowingStream<[GitCommit], any Error> {
            AsyncThrowingStream {
                $0.finish(throwing: FileSystemError.unexpected("git is not installed"))
            }
        }
    }
#endif
