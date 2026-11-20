import Foundation
import Testing
import TreewiseCore

/// A template as parts: its name, and each folder of its tree an element (ADR 0144).
@Suite struct FolderTemplatePartsTests {
    private static let at = Date(timeIntervalSince1970: 2_000_000_000)

    private static let template = FolderTemplate(
        id: "t1", name: "Household Year",
        root: FolderTree(
            name: "{year}",
            folders: [
                FolderTree(name: "Receipts", folders: [FolderTree(name: "Shops")]),
                FolderTree(name: "Tax"),
            ])
    ).withFolderIDs()

    /// The records of `template`'s parts by `device` at `minutes` after `at`.
    private static func records(
        _ template: FolderTemplate, minutes: Double = 0, device: String = "mac"
    ) -> [SyncElement: [String: SyncRecord]] {
        template.syncElements.mapValues { parts in
            parts.mapValues { value in
                SyncRecord(
                    key: SyncKey(.patternList, ""), value: value,
                    changedAt: at.addingTimeInterval(minutes * 60), device: device)
            }
        }.reduce(into: [:]) { result, entry in
            result[entry.key] = Dictionary(
                uniqueKeysWithValues: entry.value.map { part, record in
                    (
                        part,
                        SyncRecord(
                            key: SyncKey(entry.key, part), value: record.value,
                            changedAt: record.changedAt, device: device)
                    )
                })
        }
    }

    private static func paths(_ tree: FolderTree, above: String = "") -> [String] {
        let path = above.isEmpty ? tree.name : above + "/" + tree.name
        return [path] + tree.folders.flatMap { paths($0, above: path) }
    }

    @Test func readsBackFromItsParts() {
        #expect(FolderTemplate(syncID: "t1", records: Self.records(Self.template)) == Self.template)
    }

    @Test func twoDevicesGiveATemplateTheSameFolderIDs() {
        let fresh = FolderTemplate(id: "t1", name: "Household Year", root: Self.template.root)
        let unsynced = FolderTemplate(
            id: "t1", name: "Household Year",
            root: FolderTree(
                name: "{year}",
                folders: [
                    FolderTree(name: "Receipts", folders: [FolderTree(name: "Shops")]),
                    FolderTree(name: "Tax"),
                ]))
        #expect(unsynced.withFolderIDs() == fresh.withFolderIDs())
    }

    @Test func aFolderAddedAfterTheIDsGetsANewOne() throws {
        let added = try Self.template.root.adding(in: ["Tax"], named: "Shops").tree
        let template = FolderTemplate(id: "t1", name: "Household Year", root: added)
            .withFolderIDs()
        let ids = Self.ids(template.root)
        #expect(Set(ids).count == ids.count, "no two folders share an id")
    }

    private static func ids(_ tree: FolderTree) -> [String] {
        [tree.id ?? ""] + tree.folders.flatMap(ids)
    }

    @Test func aFolderAddedOnOneDeviceAndARenameOnTheOtherBothHold() throws {
        let renamed = try Self.template.root.renaming(["Tax"], to: "Taxes").tree
        let added = try Self.template.root.adding(in: ["Receipts"], named: "Online").tree
        let mac = FolderTemplate(id: "t1", name: "Household Year", root: renamed)
        let ipad = FolderTemplate(id: "t1", name: "Household Year", root: added).withFolderIDs()
        var records = Self.records(mac, minutes: 1, device: "mac")
        for (element, parts) in Self.records(ipad, minutes: 2, device: "ipad")
        where parts.mapValues(\.value) != Self.template.syncElements[element] {
            records[element] = parts
        }
        let merged = try #require(FolderTemplate(syncID: "t1", records: records))
        #expect(
            Self.paths(merged.root).sorted()
                == [
                    "{year}", "{year}/Receipts", "{year}/Receipts/Online", "{year}/Receipts/Shops",
                    "{year}/Taxes",
                ])
    }

    @Test func aRemovedFolderWithAFolderAddedInsideElsewhereStays() throws {
        var records = Self.records(Self.template)
        let tax = try #require(Self.template.root.folders.first { $0.name == "Tax" }?.id)
        records[.templateFolder(template: "t1", folder: tax)]?[SyncKey.exists] = SyncRecord(
            key: .exists(.templateFolder(template: "t1", folder: tax)), value: .bool(false),
            changedAt: Self.at.addingTimeInterval(60), device: "mac")
        let inside = SyncElement.templateFolder(template: "t1", folder: "new")
        records[inside] = [
            "exists": SyncRecord(
                key: .exists(inside), value: .bool(true),
                changedAt: Self.at.addingTimeInterval(120),
                device: "ipad"),
            "name": SyncRecord(
                key: SyncKey(inside, "name"), value: .string("2025"),
                changedAt: Self.at.addingTimeInterval(120), device: "ipad"),
            "parent": SyncRecord(
                key: SyncKey(inside, "parent"), value: .string(tax),
                changedAt: Self.at.addingTimeInterval(120), device: "ipad"),
        ]
        let merged = try #require(FolderTemplate(syncID: "t1", records: records))
        #expect(Self.paths(merged.root).contains("{year}/Tax/2025"))
    }

    @Test func crossedMovesMakeNoLoop() throws {
        var records = Self.records(Self.template)
        let receipts = try #require(Self.template.root.folders.first { $0.name == "Receipts" }?.id)
        let tax = try #require(Self.template.root.folders.first { $0.name == "Tax" }?.id)
        func move(_ folder: String, into parent: String, minutes: Double) {
            let element = SyncElement.templateFolder(template: "t1", folder: folder)
            records[element]?["parent"] = SyncRecord(
                key: SyncKey(element, "parent"), value: .string(parent),
                changedAt: Self.at.addingTimeInterval(minutes * 60), device: "mac")
        }
        move(receipts, into: tax, minutes: 1)
        move(tax, into: receipts, minutes: 2)
        let merged = try #require(FolderTemplate(syncID: "t1", records: records))
        #expect(
            Self.paths(merged.root).sorted()
                == ["{year}", "{year}/Tax", "{year}/Tax/Receipts", "{year}/Tax/Receipts/Shops"])
    }

    @Test func twoFoldersOfOneNameAreBothKept() throws {
        var records = Self.records(Self.template)
        let root = try #require(Self.template.root.id)
        let twin = SyncElement.templateFolder(template: "t1", folder: "twin")
        records[twin] = [
            "exists": SyncRecord(
                key: .exists(twin), value: .bool(true), changedAt: Self.at, device: "ipad"),
            "name": SyncRecord(
                key: SyncKey(twin, "name"), value: .string("Tax"), changedAt: Self.at,
                device: "ipad"),
            "parent": SyncRecord(
                key: SyncKey(twin, "parent"), value: .string(root), changedAt: Self.at,
                device: "ipad"),
        ]
        let merged = try #require(FolderTemplate(syncID: "t1", records: records))
        #expect(merged.root.folders.map(\.name).sorted() == ["Receipts", "Tax", "Tax 2"])
    }
}
