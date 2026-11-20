import Foundation
import Testing
import TreewiseCore

/// A folder that Treewise moves in a drive takes its settings, and those of the folders
/// inside it, to its new path on every device (ADR 0144).
@Suite struct SyncMoveTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)
    private static let earlier = now.addingTimeInterval(-60)

    /// The records of folders with settings: `exists` and one part each, or removed.
    private static func known(_ folders: [(String, String?)]) -> [SyncKey: SyncRecord] {
        var known: [SyncKey: SyncRecord] = [:]
        for (path, module) in folders {
            let element = SyncElement.folder(path)
            known[.exists(element)] = SyncRecord(
                key: .exists(element), value: .bool(module != nil), changedAt: earlier,
                device: "ipad")
            if let module {
                let key = SyncKey(element, "enabledModules")
                known[key] = SyncRecord(
                    key: key, value: .string(module), changedAt: earlier, device: "ipad")
            }
        }
        return known
    }

    private static func moved(
        _ old: String, to new: String, in known: [SyncKey: SyncRecord]
    ) -> [SyncKey: SyncRecord] {
        let records = SyncMove.records(
            movingFolder: old, to: new, known: known, at: now, device: "mac")
        return Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0) })
    }

    @Test func theOldPathIsRemovedAndTheNewOneTakesTheSettings() {
        let result = Self.moved(
            "Clients/Old", to: "Clients/New", in: Self.known([("Clients/Old", "a")]))
        #expect(result[.exists(.folder("Clients/Old"))]?.isRemoval == true)
        #expect(result[SyncKey(.folder("Clients/New"), "enabledModules")]?.value == .string("a"))
        #expect(result[.exists(.folder("Clients/New"))]?.value == .bool(true))
        #expect(result.values.allSatisfy { $0.changedAt == Self.now && $0.device == "mac" })
    }

    @Test func foldersInsideFollow() {
        let result = Self.moved(
            "Clients/Old", to: "Archive/Old", in: Self.known([("Clients/Old/2026", "b")]))
        #expect(result[.exists(.folder("Clients/Old/2026"))]?.isRemoval == true)
        #expect(
            result[SyncKey(.folder("Archive/Old/2026"), "enabledModules")]?.value == .string("b"))
    }

    @Test func aFolderWhoseNameOnlyStartsTheSameStays() {
        #expect(
            Self.moved(
                "Clients/Old", to: "Clients/New", in: Self.known([("Clients/Old copy", "c")])
            )
            .isEmpty)
    }

    @Test func aRemovedFolderMovesNothing() {
        #expect(
            Self.moved("Clients/Old", to: "Clients/New", in: Self.known([("Clients/Old", nil)]))
                .isEmpty)
    }

    @Test func patternsAndTemplatesStay() {
        let key = SyncKey(.pattern("p"), "name")
        let known = [
            key: SyncRecord(key: key, value: .string("x"), changedAt: Self.earlier, device: "ipad")
        ]
        #expect(Self.moved("Clients/Old", to: "Clients/New", in: known).isEmpty)
    }
}
