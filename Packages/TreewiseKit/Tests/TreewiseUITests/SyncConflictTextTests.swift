import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// How a replaced change reads in the safety net (ADR 0144).
@Suite struct SyncConflictTextTests {
    private static func entry(
        _ element: SyncElement, _ part: String, mine: JSONValue, theirs: JSONValue
    ) -> SyncConflictStore.Entry {
        let at = Date(timeIntervalSince1970: 2_000_000_000)
        let key = SyncKey(element, part)
        return SyncConflictStore.Entry(
            conflict: SyncBook.Conflict(
                mine: SyncRecord(key: key, value: mine, changedAt: at, device: "mac"),
                winner: SyncRecord(key: key, value: theirs, changedAt: at, device: "ipad")),
            foundAt: at, byDevice: "iPad")
    }

    @Test func aTemplatesFolderNameReadsWithTheTemplatesName() {
        let text = SyncConflictText(
            Self.entry(
                .templateFolder(template: "t1", folder: "f1"), "name", mine: .string("Taxes"),
                theirs: .string("Belasting")),
            names: { $0 == .template("t1") ? "Household Year" : nil },
            locale: Locale(identifier: "en"))
        #expect(text.title == "Household Year")
        #expect(text.part == "Folder name")
        #expect(text.yours == "Taxes")
        #expect(text.now == "Belasting")
    }

    @Test func aFoldersModulePatternReadsAsItsTemplate() {
        let text = SyncConflictText(
            Self.entry(
                .folder("Clients/Acme"), "module/dates",
                mine: .object(["template": .string("{date} {text}")]),
                theirs: .object(["template": .string("{date:yyyy} {text}")])),
            names: { _ in nil }, locale: Locale(identifier: "en"))
        #expect(text.title == "Clients/Acme")
        #expect(text.yours == "{date} {text}")
        #expect(text.now == "{date:yyyy} {text}")
    }

    @Test func aRemovalReadsAsRemoved() {
        let text = SyncConflictText(
            Self.entry(.template("t1"), "exists", mine: .bool(true), theirs: .bool(false)),
            names: { _ in "Household Year" }, locale: Locale(identifier: "en"))
        #expect(text.yours == "Kept")
        #expect(text.now == "Removed")
    }
}
