import Foundation
import TreewiseCore
import os

/// Keeps the safety net of ADR 0144 on this device: each change of this device's that
/// another device's replaced without seeing it, with when it was found and by which device,
/// for 30 days, in a file in the app's support folder.
public actor SyncConflictStore {
    /// How long a replaced change is kept: 30 days.
    public static let kept: TimeInterval = 30 * 24 * 60 * 60
    static let fileName = "sync-replaced.json"
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "Sync")

    /// A replaced change as it is kept.
    public struct Entry: Hashable, Sendable, Codable, Identifiable {
        public let conflict: SyncBook.Conflict
        /// When this device found it.
        public let foundAt: Date
        /// The name of the device whose change holds instead, if its file gave one.
        public let byDevice: String?

        public var id: String {
            "\(conflict.mine.key.order)\u{0}\(conflict.mine.changedAt.timeIntervalSince1970)"
        }

        public init(conflict: SyncBook.Conflict, foundAt: Date, byDevice: String?) {
            self.conflict = conflict
            self.foundAt = foundAt
            self.byDevice = byDevice
        }
    }

    private let file: URL

    /// A store in `directory`.
    public init(directory: URL) {
        file = directory.appending(path: Self.fileName)
    }

    /// The entries kept, newest first, without those older than `kept` before `now`.
    public func entries(now: Date) -> [Entry] {
        guard let data = try? Data(contentsOf: file),
            let all = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return all.filter { now.timeIntervalSince($0.foundAt) <= Self.kept }
            .sorted { $0.foundAt > $1.foundAt }
    }

    /// Adds `entries`, keeping the file to those not older than `kept`.
    public func add(_ entries: [Entry], now: Date) {
        save(entries + self.entries(now: now), now: now)
    }

    /// Removes `entry`, as Restore did it.
    public func remove(_ entry: Entry, now: Date) {
        save(entries(now: now).filter { $0 != entry }, now: now)
    }

    /// Removes every entry.
    public func clear() {
        save([], now: .now)
    }

    private func save(_ entries: [Entry], now: Date) {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        } catch {
            Self.logger.error("Replaced changes not kept: \(error.localizedDescription)")
        }
    }
}
