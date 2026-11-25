import Foundation
import Observation
import TreewiseCore

/// The git state of the working copies the windows show: one for each repository, read
/// once for every tab and window that shows a folder in it, and read again a moment after
/// it changes (ADR 0149). Reading happens in the background: the state shown stays until
/// the new one is there, and browsing never waits for it.
///
/// Turned off, it runs no git and follows nothing; the folders shown are kept, so turning
/// it on reads their repositories again.
@MainActor
@Observable
public final class GitStatusModel {
    /// How long it waits after a change before reading again, so a burst of saves is
    /// read once.
    public static let pause = Duration.milliseconds(500)

    @ObservationIgnored private let reader: any GitStatusReading
    @ObservationIgnored private let pause: Duration
    /// How many tabs show each folder, whether or not it is in a repository.
    @ObservationIgnored private var shown: [FileItem.ID: Int] = [:]
    /// The repository of each shown folder that is in one, once found.
    @ObservationIgnored private var repositories: [FileItem.ID: GitRepository] = [:]
    /// The folders that hold no repository, so they are not looked for again.
    @ObservationIgnored private var outside: Set<FileItem.ID> = []
    /// The reading of each followed repository: once at first, then after each change.
    @ObservationIgnored private var updates: [GitRepository: Task<Void, Never>] = [:]
    /// Each followed repository's state, once read.
    private var statuses: [GitRepository: GitRepositoryStatus] = [:]

    /// Whether git status shows; off, nothing is read or followed.
    public var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled {
                for folder in shown.keys { Task { await self.find(folder) } }
            } else {
                stopAll()
            }
        }
    }

    /// Whether a git is installed that Treewise can run.
    public var hasGit: Bool { reader.hasGit }

    /// A model that reads with `reader`, waiting `pause` after a change.
    public init(reader: any GitStatusReading, isEnabled: Bool = true, pause: Duration = pause) {
        self.reader = reader
        self.isEnabled = isEnabled
        self.pause = pause
    }

    /// Follows the repository that holds `folder` while a tab shows it: returns when the
    /// calling task is cancelled, also for a folder outside a repository, which is looked
    /// for again when the setting is turned on.
    public func follow(_ folder: FileItem.ID) async {
        shown[folder, default: 0] += 1
        await find(folder)
        await Self.untilCancelled()
        shown[folder, default: 1] -= 1
        guard shown[folder] == 0 else { return }
        shown[folder] = nil
        if let repository = repositories.removeValue(forKey: folder) { stopIfUnshown(repository) }
    }

    /// The state of the repository that holds `folder`; `nil` outside one, before it is
    /// read, or while turned off.
    public func status(of folder: FileItem.ID) -> GitRepositoryStatus? {
        repositories[folder].flatMap { statuses[$0] }
    }

    /// The state of `item`, which a tab shows in `folder`; `nil` when it is unchanged or
    /// its state is not known.
    public func state(of item: FileItem.ID, in folder: FileItem.ID) -> GitItemState? {
        guard let repository = repositories[folder], let status = statuses[repository],
            let path = reader.relativePath(of: item, in: repository)
        else { return nil }
        return status.state(of: path)
    }

    /// Whether the sidebar marks `folder` as a repository's top folder.
    public func marksRepository(_ folder: FileItem.ID) -> Bool {
        isEnabled && reader.isRepositoryTop(folder)
    }

    /// Finds the repository of a shown folder and follows it, unless it is known.
    private func find(_ folder: FileItem.ID) async {
        guard isEnabled, repositories[folder] == nil, !outside.contains(folder) else { return }
        guard let repository = await reader.repository(holding: folder) else {
            outside.insert(folder)
            return
        }
        // While git looked, the tab may have moved on, or the setting turned off.
        guard isEnabled, shown[folder] != nil else { return }
        repositories[folder] = repository
        if updates[repository] == nil {
            updates[repository] = Task { await self.keepUpToDate(repository) }
        }
    }

    /// Reads the repository now and again after each change, until cancelled.
    private func keepUpToDate(_ repository: GitRepository) async {
        let changes = reader.changes(of: repository)
        await read(repository)
        for await _ in changes {
            // Changes during the pause and the read wait as one, read once after it.
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            await read(repository)
        }
    }

    private func read(_ repository: GitRepository) async {
        guard let status = try? await reader.status(of: repository), !Task.isCancelled else {
            return
        }
        statuses[repository] = status
    }

    /// Stops following `repository` when no shown folder is in it any more.
    private func stopIfUnshown(_ repository: GitRepository) {
        guard !repositories.values.contains(repository) else { return }
        updates.removeValue(forKey: repository)?.cancel()
        statuses[repository] = nil
    }

    private func stopAll() {
        for update in updates.values { update.cancel() }
        updates = [:]
        repositories = [:]
        outside = []
        statuses = [:]
    }

    /// Returns when the calling task is cancelled.
    private static func untilCancelled() async {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        for await _ in stream {}
        // Used after the loop, so the stream does not end before the task is cancelled.
        continuation.finish()
    }
}
