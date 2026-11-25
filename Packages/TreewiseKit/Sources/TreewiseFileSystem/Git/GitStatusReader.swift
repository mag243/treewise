#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Reads the git state of working copies on the local disk with the user's own git,
    /// never changing them (ADR 0149).
    public struct GitStatusReader: GitStatusReading {
        /// The git to run; `nil` when none is installed.
        public let tool: GitTool?

        /// The entries of the git data whose change can change the state: where HEAD
        /// points, the index, the branches and a merge under way.
        private static let watchedGitEntries: Set<String> = [
            "HEAD", "index", "packed-refs", "MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD",
        ]

        /// Creates a reader that runs `tool`, by default the git `GitTool.find` finds.
        public init(tool: GitTool? = GitTool.find()) {
            self.tool = tool
        }

        public var hasGit: Bool { tool != nil }

        public func repository(holding folder: FileItem.ID) async -> GitRepository? {
            let path = folder.rawValue
            guard let tool, Self.hasGitEntry(above: path),
                let data = try? await GitProcess.run(
                    tool, in: path,
                    ["rev-parse", "--is-inside-work-tree", "--show-cdup", "--absolute-git-dir"])
            else { return nil }
            // A line each, in the order asked; the last, a path, may hold a newline itself.
            let lines = (String(bytes: data, encoding: .utf8) ?? "")
                .split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
            guard lines.count == 3, lines[0] == "true" else { return nil }
            // `--show-cdup` says how far up the top folder is as `../` for each level, so
            // the top is found in the folder's own terms, such as /var for /private/var.
            let levels = lines[1].components(separatedBy: "../").count - 1
            var top = path
            for _ in 0..<levels { top = (top as NSString).deletingLastPathComponent }
            let gitDirectory = String(lines[2]).trimmingCharacters(in: .newlines)
            return GitRepository(top: FileItem.ID(top), gitDirectory: gitDirectory)
        }

        public func status(of repository: GitRepository) async throws -> GitRepositoryStatus {
            guard let tool else { throw FileSystemError.unexpected("git is not installed") }
            let data = try await GitProcess.run(
                tool, in: repository.top.rawValue,
                ["status", "--porcelain=v2", "--branch", "-z", "--ignored"])
            return GitRepositoryStatus(porcelain: data)
        }

        public func changes(of repository: GitRepository) -> AsyncStream<Void> {
            AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
                guard let top = FileEvents.realPath(repository.top.rawValue),
                    let git = FileEvents.realPath(repository.gitDirectory)
                else {
                    continuation.finish()
                    return
                }
                let trees = git.hasPrefix(top + "/") ? [top] : [top, git]
                let stop = FileEvents.watch(
                    trees: trees, accepts: { Self.changesState($0, gitDirectory: git) },
                    onChange: { continuation.yield() })
                guard let stop else {
                    continuation.finish()
                    return
                }
                continuation.onTermination = { _ in stop() }
            }
        }

        public func relativePath(of item: FileItem.ID, in repository: GitRepository) -> String? {
            let top = repository.top.rawValue
            let path = item.rawValue
            if path == top { return "" }
            let prefix = top.hasSuffix("/") ? top : top + "/"
            return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : nil
        }

        public func isRepositoryTop(_ folder: FileItem.ID) -> Bool {
            FileManager.default.fileExists(atPath: folder.rawValue + "/.git")
        }

        /// Whether `path` or a folder above it holds a `.git`, a folder or the file of a
        /// worktree: without one there is no working copy, and git need not run.
        static func hasGitEntry(above path: String) -> Bool {
            var folder = path
            while true {
                if FileManager.default.fileExists(atPath: folder + "/.git") { return true }
                let parent = (folder as NSString).deletingLastPathComponent
                if parent == folder || parent.isEmpty { return false }
                folder = parent
            }
        }

        /// Whether a change at `path` can change the state: anything in the working copy,
        /// but in the git data only HEAD, the index and the branches, not the objects and
        /// logs git writes along with them.
        static func changesState(_ path: String, gitDirectory: String) -> Bool {
            let prefix = gitDirectory + "/"
            guard path.hasPrefix(prefix) else { return path != gitDirectory }
            let inside = path.dropFirst(prefix.count)
            return watchedGitEntries.contains(String(inside)) || inside.hasPrefix("refs/")
        }
    }
#endif
