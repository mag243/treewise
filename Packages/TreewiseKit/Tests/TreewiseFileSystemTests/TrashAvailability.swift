import Foundation
import TreewiseTestSupport

/// Whether items in a TempDirectory can go to a Trash. The Mac's can; the
/// iOS Simulator's test process has no Trash anywhere (ADR 0047), so tests
/// that need one run only where there is one.
enum TrashAvailability {
    static let inTemporaryDirectory: Bool = {
        guard let directory = try? TempDirectory(),
            let probe = try? directory.makeFile("Treewise trash probe \(UUID().uuidString)")
        else { return false }
        var trashed: NSURL?
        guard (try? FileManager.default.trashItem(at: probe, resultingItemURL: &trashed)) != nil,
            let trashed = trashed as URL?
        else { return false }
        // Take the probe back out of the Trash, as every trash test does (ADR 0018).
        try? FileManager.default.moveItem(at: trashed, to: probe)
        return true
    }()
}
