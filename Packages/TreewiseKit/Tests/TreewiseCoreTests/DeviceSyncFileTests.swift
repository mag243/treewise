import Foundation
import Testing
import TreewiseCore

/// A device's file in a drive's `.treewise` folder (ADR 0144): versioned, read back as
/// written, and a newer format reported rather than guessed.
@Suite struct DeviceSyncFileTests {
    private static let at = Date(timeIntervalSince1970: 2_000_000_000.25)

    private static var file: DeviceSyncFile {
        let template = FolderTemplate(
            id: "t1", name: "Household Year",
            root: FolderTree(name: "{year}", folders: [FolderTree(name: "Receipts")]))
        return DeviceSyncFile(
            device: "4C1F", name: "Office Mac",
            records: [
                SyncRecord(
                    key: .folder("Clients/2026"),
                    value: .folder(FolderSettings(enabledModules: ["dates"], templates: [:])),
                    changedAt: at, device: "4C1F"),
                SyncRecord(
                    key: .savedPattern("p1"),
                    value: .savedPattern(SavedPattern(id: "p1", name: "Invoices", text: "{date}")),
                    changedAt: at, device: "4C1F"),
                SyncRecord(
                    key: .defaultPattern, value: .defaultPattern(id: "p1"), changedAt: at,
                    device: "4C1F"),
                SyncRecord(
                    key: .template("t1"), value: .template(template), changedAt: at, device: "4C1F"),
                SyncRecord(key: .folder("Clients/Old"), value: nil, changedAt: at, device: "4C1F"),
            ])
    }

    @Test func readsBackWhatItWrote() throws {
        let written = try Self.file.encoded()
        #expect(try DeviceSyncFile.decoded(from: written) == Self.file)
    }

    @Test func aNewerFormatIsReported() throws {
        let newer = Data(#"{"format": 2, "device": "X", "name": "", "records": []}"#.utf8)
        #expect(throws: DeviceSyncFile.Problem.newerFormat(2)) {
            try DeviceSyncFile.decoded(from: newer)
        }
    }

    @Test func aRecordOfAnUnknownKindIsSkippedAndTheRestRead() throws {
        let text = #"""
            {"format": 1, "device": "X", "name": "iPad", "records": [
              {"key": "bookmark/1", "changedAt": 1, "device": "X", "value": {"anything": 1}},
              {"key": "template/t1", "changedAt": 1, "device": "X"}
            ]}
            """#
        let file = try DeviceSyncFile.decoded(from: Data(text.utf8))
        #expect(file.records.map(\.key) == [.template("t1")])
    }

    @Test(arguments: [
        SyncKey.folder("Clients/2026/Q1"), .savedPattern("p/1"), .defaultPattern, .template("t1"),
    ])
    func aKeyReadsBackFromItsText(_ key: SyncKey) {
        #expect(SyncKey(text: key.text) == key)
    }

    @Test func aKeyOfAnUnknownKindIsNone() {
        #expect(SyncKey(text: "bookmark/1") == nil)
    }
}
