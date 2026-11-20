import Foundation
import Observation
import TreewiseCore
import TreewiseFileSystem

/// The app's side of syncing through the cloud drives (ADR 0144): starts and stops the
/// sync with the switch, hands the saved patterns between the settings and the sync, reads
/// the drives again when asked, and keeps the safety net: this device's changes another
/// device's replaced without seeing them, with Restore.
@MainActor
@Observable
public final class SyncController {
    /// The changes of this device's another device's replaced, newest first.
    public private(set) var replaced: [SyncConflictStore.Entry] = []
    /// The roots of the drives that take part.
    public private(set) var drives: [URL] = []
    /// Why this device does not sync in a drive, by the drive's path: no sync folder yet,
    /// or one the provider renamed (ADR 0144).
    public private(set) var driveProblems: [String: SyncFolder.Problem] = [:]

    @ObservationIgnored private let settings: BrowserSettings
    @ObservationIgnored private let session: SyncSession
    @ObservationIgnored private let conflicts: SyncConflictStore
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var isRunning = false
    /// The saved patterns' changes, told to the sync one after another.
    @ObservationIgnored private var patternChanges: Task<Void, Never>?

    /// A controller of `session` for `settings`, keeping the safety net in `conflicts`.
    public init(
        settings: BrowserSettings, session: SyncSession, conflicts: SyncConflictStore,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.settings = settings
        self.session = session
        self.conflicts = conflicts
        self.now = now
    }

    /// Starts syncing through the drives at `drives` when the switch is on; when it runs,
    /// syncs through these drives from now on.
    public func start(drives: [URL]) async {
        let changed = drives != self.drives
        self.drives = drives
        replaced = await conflicts.entries(now: now())
        guard settings.syncsSettings else { return }
        if isRunning {
            if changed {
                take(await session.changeDrives(drives))
                await keepConflicts()
            }
            return
        }
        isRunning = true
        take(await session.start(drives: drives, patterns: settings.savedPatterns))
        settings.savedPatternsChanged = { [weak self] before, after in
            self?.tell(from: before, to: after)
        }
        await keepConflicts()
    }

    /// Turns syncing on or off, as the switch in Settings does.
    public func setSyncing(_ isOn: Bool) async {
        settings.syncsSettings = isOn
        if isOn {
            await start(drives: drives)
        } else {
            settings.savedPatternsChanged = nil
            await session.stop()
            isRunning = false
        }
    }

    /// Reads the drives' files again and takes over what other devices changed.
    public func refresh() async {
        guard isRunning else { return }
        await settle()
        take(await session.refresh())
        await keepConflicts()
    }

    /// Returns once every change made so far is recorded and written.
    public func settle() async {
        await patternChanges?.value
        await session.settle()
    }

    /// Restore: this device's value of `entry` holds again, here and on the other devices.
    public func restore(_ entry: SyncConflictStore.Entry) async {
        take(await session.restore(entry.conflict))
        await conflicts.remove(entry, now: now())
        replaced = await conflicts.entries(now: now())
    }

    /// Forgets every replaced change.
    public func clearReplaced() async {
        await conflicts.clear()
        replaced = []
    }

    private func tell(from before: SavedPatterns, to after: SavedPatterns) {
        let previous = patternChanges
        let session = session
        patternChanges = Task {
            await previous?.value
            await session.patternsChanged(from: before, to: after)
        }
    }

    private func take(_ changes: [SettingsSync.Change]) {
        for case .savedPatterns(let patterns) in changes { settings.takeOver(patterns) }
    }

    private func keepConflicts() async {
        driveProblems = await session.driveProblems()
        let found = await session.conflicts
        guard !found.isEmpty else { return }
        await session.clearConflicts()
        var entries: [SyncConflictStore.Entry] = []
        for conflict in found {
            entries.append(
                SyncConflictStore.Entry(
                    conflict: conflict, foundAt: now(),
                    byDevice: await session.deviceName(conflict.winner.device)))
        }
        await conflicts.add(entries, now: now())
        replaced = await conflicts.entries(now: now())
    }
}
