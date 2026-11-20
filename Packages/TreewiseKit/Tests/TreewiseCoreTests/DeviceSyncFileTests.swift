import Foundation
import Testing
import TreewiseCore

/// A device's file in a drive's `.treewise` folder (ADR 0144): versioned, read back as
/// written, and a newer format reported rather than guessed.
@Suite struct DeviceSyncFileTests {
    private static let at = Date(timeIntervalSince1970: 2_000_000_000.25)

    private static let file = DeviceSyncFile(
        device: "4C1F", name: "Office Mac",
        records: [
            SyncRecord(
                key: SyncKey(.folder("Clients/2026"), "enabledModules"),
                value: .array([.string("dates")]), changedAt: at, device: "4C1F",
                replaced: SyncStamp(device: "ipad", changedAt: at.addingTimeInterval(-60))),
            SyncRecord(
                key: SyncKey(.pattern("p1"), "name"), value: .string("Invoices"), changedAt: at,
                device: "4C1F"),
            SyncRecord(
                key: SyncKey(.patternList, "default"), value: .string("p1"), changedAt: at,
                device: "4C1F"),
            SyncRecord(
                key: SyncKey(.templateFolder(template: "t1", folder: "f/1"), "parent"),
                value: .string(""), changedAt: at, device: "4C1F"),
            SyncRecord(
                key: .exists(.folder("Clients/Old")), value: .bool(false), changedAt: at,
                device: "4C1F"),
        ])

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
              {"element": {"kind": "bookmark", "id": "1"}, "part": "x", "changedAt": 1,
               "device": "X", "value": 1},
              {"element": {"kind": "template", "id": "t1"}, "part": "name", "changedAt": 1,
               "device": "X", "value": "Year"}
            ]}
            """#
        let file = try DeviceSyncFile.decoded(from: Data(text.utf8))
        #expect(file.records.map(\.key) == [SyncKey(.template("t1"), "name")])
    }

    @Test func aPathWithSlashesAndHashesReadsBack() throws {
        let key = SyncKey(.folder("A/B#2/C: D"), "alwaysSkipped/x/y.pdf")
        let file = DeviceSyncFile(
            device: "X", name: "",
            records: [SyncRecord(key: key, value: .bool(true), changedAt: Self.at, device: "X")])
        #expect(try DeviceSyncFile.decoded(from: file.encoded()).records.first?.key == key)
    }
}
