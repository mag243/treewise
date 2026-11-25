import Foundation
import Synchronization
import TreewiseCore

/// A git reader whose repositories, states and changes a test sets by hand.
public final class ScriptedGitReader: GitStatusReading {
    private struct Script {
        var repositories: [FileItem.ID: GitRepository] = [:]
        var statuses: [GitRepository: GitRepositoryStatus] = [:]
        var reads: [GitRepository: Int] = [:]
        var lookups = 0
        var watching: [GitRepository: [UUID: AsyncStream<[String]>.Continuation]] = [:]
    }

    private let script = Mutex(Script())
    public let hasGit: Bool

    /// Creates a reader without repositories; `hasGit` false for a Mac without git.
    public init(hasGit: Bool = true) {
        self.hasGit = hasGit
    }

    /// Makes `top` a working copy whose state is read as `porcelain`; every folder whose id
    /// starts with it, followed by `/`, is in it.
    @discardableResult
    public func addRepository(at top: FileItem.ID, porcelain: String) -> GitRepository {
        let repository = GitRepository(top: top, gitDirectory: top.rawValue + "/.git")
        script.withLock {
            $0.repositories[top] = repository
            $0.statuses[repository] = Self.status(porcelain)
        }
        return repository
    }

    /// Sets the state the next read of `repository` gives.
    public func setStatus(of repository: GitRepository, porcelain: String) {
        script.withLock { $0.statuses[repository] = Self.status(porcelain) }
    }

    /// How often `repository`'s state was read.
    public func reads(of repository: GitRepository) -> Int {
        script.withLock { $0.reads[repository] ?? 0 }
    }

    /// How often a folder's repository was looked for.
    public var lookups: Int { script.withLock { $0.lookups } }

    /// The repositories someone follows right now.
    public var watchedRepositories: Set<GitRepository> {
        script.withLock { Set($0.watching.filter { !$0.value.isEmpty }.keys) }
    }

    /// Reports a change of `paths` in `repository`, from its top folder, to everyone
    /// following it; by default one in its git data.
    public func change(_ repository: GitRepository, paths: [String] = [""]) {
        let watching = script.withLock { Array(($0.watching[repository] ?? [:]).values) }
        for continuation in watching { continuation.yield(paths) }
    }

    public func repository(holding folder: FileItem.ID) async -> GitRepository? {
        guard hasGit else { return nil }
        return script.withLock { script in
            script.lookups += 1
            return script.repositories.first { top, _ in
                folder == top || folder.rawValue.hasPrefix(top.rawValue + "/")
            }?.value
        }
    }

    public func status(of repository: GitRepository) async throws -> GitRepositoryStatus {
        script.withLock {
            $0.reads[repository, default: 0] += 1
            return $0.statuses[repository] ?? GitRepositoryStatus()
        }
    }

    public func changes(of repository: GitRepository) -> AsyncStream<[String]> {
        let (stream, continuation) = AsyncStream<[String]>.makeStream()
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.script.withLock { $0.watching[repository]?[id] = nil }
        }
        script.withLock { $0.watching[repository, default: [:]][id] = continuation }
        return stream
    }

    public func relativePath(of item: FileItem.ID, in repository: GitRepository) -> String? {
        let top = repository.top.rawValue
        if item.rawValue == top { return "" }
        return item.rawValue.hasPrefix(top + "/")
            ? String(item.rawValue.dropFirst(top.count + 1)) : nil
    }

    public func isRepositoryTop(_ folder: FileItem.ID) -> Bool {
        script.withLock { $0.repositories[folder] != nil }
    }

    /// The state of records written one to a line, as git writes them ending in a 0 byte.
    private static func status(_ porcelain: String) -> GitRepositoryStatus {
        let records = porcelain.split(separator: "\n").map { $0 + "\0" }.joined()
        return GitRepositoryStatus(porcelain: Data(records.utf8))
    }
}
