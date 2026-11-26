import Foundation
import Observation
import TreewiseCore

/// The git state of the working copies the windows show: one for each repository, read
/// once for every tab and window that shows a folder in it, and read again a moment after
/// it changes (ADR 0149). Reading happens in the background: the state shown stays until
/// the new one is there, and browsing never waits for it. A change only to items git
/// ignores, such as a build writing its output, is not read again.
///
/// Turned off, it runs no git and follows nothing; the folders shown are kept, so turning
/// it on reads their repositories again.
@MainActor
@Observable
public final class GitStatusModel {
    /// How long it waits after a change before reading again, so a burst of saves is
    /// read once.
    public static let pause = Duration.milliseconds(500)

    @ObservationIgnored private var reader: any GitStatusReading
    /// Counts the readers used, so a repository a former one found is not followed.
    @ObservationIgnored private var readerGeneration = 0
    @ObservationIgnored private let wait: @Sendable () async -> Void
    /// How many tabs show each folder, whether or not it is in a repository.
    @ObservationIgnored private var shown: [FileItem.ID: Int] = [:]
    /// The repository of each shown folder that is in one, once found. Observed, as the
    /// states are, so a view that asked before it was found hears when it is.
    private var repositories: [FileItem.ID: GitRepository] = [:]
    /// The shown folders that hold no repository, so they are not looked for again while
    /// shown.
    @ObservationIgnored private var outside: Set<FileItem.ID> = []
    /// The reading of each followed repository: once at first, then after its changes.
    @ObservationIgnored private var updates: [GitRepository: Task<Void, Never>] = [:]
    /// Each followed repository's state, once read.
    private var statuses: [GitRepository: GitRepositoryStatus] = [:] {
        didSet { revision &+= 1 }
    }
    /// Changes whenever a repository's state is read or forgotten, for a view that shows
    /// states it asks for one by one, as the sidebar tree, to hear when to ask again.
    public private(set) var revision = 0
    /// Whether a git is installed that Treewise can run.
    public private(set) var hasGit: Bool

    /// Whether git status shows; off, nothing is read or followed.
    public var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled { findShownFolders() } else { stopAll() }
        }
    }

    /// A model that reads with `reader`, waiting `pause` after a change.
    public convenience init(
        reader: any GitStatusReading, isEnabled: Bool = true, pause: Duration = pause
    ) {
        self.init(reader: reader, isEnabled: isEnabled) { try? await Task.sleep(for: pause) }
    }

    /// A model that reads with `reader`, running `wait` after a change before it reads.
    public init(
        reader: any GitStatusReading, isEnabled: Bool = true,
        wait: @escaping @Sendable () async -> Void
    ) {
        self.reader = reader
        self.isEnabled = isEnabled
        self.wait = wait
        hasGit = reader.hasGit
    }

    /// Reads with `reader` from now on, as after git was installed, and reads the shown
    /// folders' repositories again.
    public func use(_ reader: any GitStatusReading) {
        stopAll()
        self.reader = reader
        readerGeneration += 1
        hasGit = reader.hasGit
        if isEnabled { findShownFolders() }
    }

    /// Follows the repository that holds `folder` while a tab shows it: returns when the
    /// calling task is cancelled, also for a folder outside a repository, which is looked
    /// for again when it is shown again or the setting is turned on.
    public func follow(_ folder: FileItem.ID) async {
        shown[folder, default: 0] += 1
        await find(folder)
        await Self.untilCancelled()
        shown[folder, default: 1] -= 1
        guard shown[folder] == 0 else { return }
        shown[folder] = nil
        outside.remove(folder)
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

    /// The state of a folder the sidebar tree shows, in whichever followed repository holds
    /// it, by the list's folder rules; `nil` for a repository's top folder, which the tree
    /// marks instead, outside a followed repository, or while turned off. The tree follows
    /// a repository whose top folder it shows open with `follow(_:)`.
    public func state(ofFolder folder: FileItem.ID) -> GitItemState? {
        guard isEnabled else { return nil }
        // The innermost repository holds it, as a submodule inside another.
        let innermostFirst = statuses.sorted {
            $0.key.top.rawValue.count > $1.key.top.rawValue.count
        }
        for (repository, status) in innermostFirst {
            guard let path = reader.relativePath(of: folder, in: repository) else { continue }
            return path.isEmpty ? nil : status.state(of: path)
        }
        return nil
    }

    /// Whether the sidebar marks `folder` as a repository's top folder.
    public func marksRepository(_ folder: FileItem.ID) -> Bool {
        isEnabled && reader.isRepositoryTop(folder)
    }

    private func findShownFolders() {
        for folder in shown.keys { Task { await self.find(folder) } }
    }

    /// Finds the repository of a shown folder and follows it, unless it is known.
    private func find(_ folder: FileItem.ID) async {
        guard isEnabled, repositories[folder] == nil, !outside.contains(folder) else { return }
        let generation = readerGeneration
        let repository = await reader.repository(holding: folder)
        // While git looked, the tab may have moved on, the setting turned off or git come.
        guard isEnabled, shown[folder] != nil, generation == readerGeneration else { return }
        guard let repository else {
            outside.insert(folder)
            return
        }
        repositories[folder] = repository
        if updates[repository] == nil {
            updates[repository] = Task { await self.keepUpToDate(repository) }
        }
    }

    /// Reads the repository now and again after the changes that matter, until cancelled.
    private func keepUpToDate(_ repository: GitRepository) async {
        let changes = reader.changes(of: repository)
        let rereading = Rereading(wait: wait) { [weak self] in await self?.read(repository) }
        await read(repository)
        for await paths in changes where matters(paths, in: repository) {
            rereading.request()
        }
        rereading.cancel()
    }

    /// Whether a change of `paths` can change the state: not when each was ignored by
    /// the last reading.
    private func matters(_ paths: [String], in repository: GitRepository) -> Bool {
        guard let status = statuses[repository] else { return true }
        return paths.contains { status.state(of: $0) != .ignored }
    }

    private func read(_ repository: GitRepository) async {
        let status = try? await reader.status(of: repository)
        // The repository may have stopped being followed while git ran.
        guard let status, updates[repository] != nil else { return }
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

/// Reads a repository again after a change: changes before the read starts are read with
/// it, changes during the read once more after it.
@MainActor
private final class Rereading {
    private let wait: @Sendable () async -> Void
    private let read: @MainActor () async -> Void
    private var isRequested = false
    private var run: Task<Void, Never>?

    init(wait: @escaping @Sendable () async -> Void, read: @escaping @MainActor () async -> Void) {
        self.wait = wait
        self.read = read
    }

    func request() {
        isRequested = true
        guard run == nil else { return }
        run = Task {
            while isRequested, !Task.isCancelled {
                await wait()
                guard !Task.isCancelled else { break }
                isRequested = false
                await read()
            }
            run = nil
        }
    }

    func cancel() {
        run?.cancel()
        isRequested = false
    }
}
