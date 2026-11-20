import Foundation
import Testing
import TreewiseCore

/// A folder that Treewise moves in a drive takes its settings, and those of the folders
/// inside it, to its new path on every device (ADR 0144).
@Suite struct SyncMoveTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)
    private static let earlier = now.addingTimeInterval(-60)

    private static func settings(_ module: String) -> SyncValue {
        .folder(FolderSettings(enabledModules: [module], templates: [:]))
    }

    private static func known(_ entries: [(SyncKey, SyncValue?)]) -> [SyncKey: SyncRecord] {
        Dictionary(
            uniqueKeysWithValues: entries.map { key, value in
                (key, SyncRecord(key: key, value: value, changedAt: earlier, device: "ipad"))
            })
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
            "Clients/Old", to: "Clients/New",
            in: Self.known([(.folder("Clients/Old"), Self.settings("a"))]))
        #expect(result[.folder("Clients/Old")]?.value == nil)
        #expect(result[.folder("Clients/Old")] != nil, "a removal, not nothing")
        #expect(result[.folder("Clients/New")]?.value == Self.settings("a"))
        #expect(result.values.allSatisfy { $0.changedAt == Self.now && $0.device == "mac" })
    }

    @Test func foldersInsideFollow() {
        let result = Self.moved(
            "Clients/Old", to: "Archive/Old",
            in: Self.known([(.folder("Clients/Old/2026"), Self.settings("b"))]))
        #expect(result[.folder("Clients/Old/2026")]?.value == nil)
        #expect(result[.folder("Archive/Old/2026")]?.value == Self.settings("b"))
    }

    @Test func aFolderWhoseNameOnlyStartsTheSameStays() {
        let result = Self.moved(
            "Clients/Old", to: "Clients/New",
            in: Self.known([(.folder("Clients/Old copy"), Self.settings("c"))]))
        #expect(result.isEmpty)
    }

    @Test func aRemovedFolderMovesNothing() {
        let result = Self.moved(
            "Clients/Old", to: "Clients/New", in: Self.known([(.folder("Clients/Old"), nil)]))
        #expect(result.isEmpty)
    }

    @Test func patternsAndTemplatesStay() {
        let pattern = SavedPattern(id: "p", name: "Invoices", text: "{date} {text}")
        let result = Self.moved(
            "Clients/Old", to: "Clients/New",
            in: Self.known([(.savedPattern("p"), .savedPattern(pattern))]))
        #expect(result.isEmpty)
    }
}
