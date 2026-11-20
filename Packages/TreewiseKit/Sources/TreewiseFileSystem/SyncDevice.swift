import Foundation
import os

/// This installation as a device that syncs (ADR 0144): a random id, made once and kept in
/// the app's support folder, never a hardware id, and a name for people.
public struct SyncDevice: Hashable, Sendable {
    /// The file in the support folder that keeps the id.
    static let fileName = "sync-device-id"
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "sync")

    /// The random id.
    public let id: String
    /// The name the system gives the device, as the app reads it.
    public let name: String

    /// A device of `id` named `name`.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// This installation's device: its id read from `directory`, or made and kept there
    /// the first time. When it cannot be kept, the id lasts until the app quits.
    public static func load(from directory: URL, name: String) -> SyncDevice {
        let file = directory.appending(path: fileName)
        if let kept = try? String(contentsOf: file, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !kept.isEmpty
        {
            return SyncDevice(id: kept, name: name)
        }
        let id = UUID().uuidString
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try Data(id.utf8).write(to: file, options: .atomic)
        } catch {
            logger.error("Sync device id not kept: \(error.localizedDescription)")
        }
        return SyncDevice(id: id, name: name)
    }
}
